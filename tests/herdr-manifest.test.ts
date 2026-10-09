import { describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync, symlinkSync, lstatSync, readlinkSync } from "node:fs";
import { join, resolve, relative } from "node:path";

const manifestPath = resolve("bucket/herdr.json");
const sourcePath = resolve("src/bucket/herdr.json");
const runner = resolve("tests/herdr-hooks.ps1");
const artifacts = resolve("workdir/herdr/tests");
mkdirSync(artifacts, { recursive: true });
const testRoot = mkdtempSync(join(artifacts, "run-"));
const runtimes = ["pwsh"];

function fixture(name: string, localKind = "directory") {
    const root = join(testRoot, name);
    for (const dir of ["roaming", "local", "persist/roaming", "foreign", "app"]) mkdirSync(join(root, dir), { recursive: true });
    writeFileSync(join(root, "persist/roaming/keep.txt"), "config-preserved");
    if (localKind === "directory") { mkdirSync(join(root, "persist/local")); writeFileSync(join(root, "persist/local/keep.txt"), "state-preserved"); }
    if (localKind === "persist-file") writeFileSync(join(root, "persist/local"), "not-a-directory");
    if (localKind === "persist-link") symlinkSync(join(root, "foreign"), join(root, "persist/local"), "dir");
    return { root, source: join(root, "roaming/herdr"), second: join(root, "local/herdr"), target: join(root, "persist/roaming") };
}

function snapshot(path: string): string {
    try {
        const stat = lstatSync(path);
        if (stat.isSymbolicLink()) return `link:${readlinkSync(path)}`;
        if (stat.isFile()) return `file:${readFileSync(path, "utf8")}`;
        return "directory";
    } catch (error) {
        if (error instanceof Error && "code" in error && error.code === "ENOENT") return "missing";
        throw error;
    }
}

async function hook(runtime: string, root: string, phase: string, denyListing = false, fault = "none") {
    const child = Bun.spawn([runtime, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", runner, "-Root", root, "-Manifest", manifestPath, "-Phase", phase, "-Fault", fault, ...(denyListing ? ["-DenyListing"] : [])], { stdout: "pipe", stderr: "pipe" });
    const [stdout, stderr, exitCode] = await Promise.all([new Response(child.stdout).text(), new Response(child.stderr).text(), child.exited]);
    writeFileSync(join(root, `${phase}-${Date.now()}.log`), `${stdout}\n${stderr}`);
    return { exitCode, output: stdout + stderr };
}

test("generated manifest preserves source hooks and update asset", () => {
    const source = JSON.parse(readFileSync(sourcePath, "utf8"));
    const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
    expect(manifest.pre_install).toEqual(source.pre_install);
    expect(manifest.portableProfile).toBeUndefined();
    expect(manifest.architecture).toEqual(source.architecture);
    expect(manifest.autoupdate.architecture["64bit"].url.replace("$version", manifest.version)).toBe(manifest.architecture["64bit"].url);
});

for (const runtime of runtimes) {
    describe(runtime, () => {
        test("fresh install and repeated mapping keep data through uninstall", async () => {
            const { root, source, second, target } = fixture(`${runtime === "pwsh" ? "7" : "5"}-lifecycle`);
            expect((await hook(runtime, root, "pre_install")).exitCode).toBe(0);
            expect((await hook(runtime, root, "post_install")).exitCode).toBe(0);
            expect(lstatSync(source).isSymbolicLink()).toBe(true);
            expect(lstatSync(second).isSymbolicLink()).toBe(true);
            expect(resolve(readlinkSync(source))).toBe(target);
            expect(readFileSync(join(source, "keep.txt"), "utf8")).toBe("config-preserved");
            expect((await hook(runtime, root, "pre_install")).exitCode).toBe(0);
            expect((await hook(runtime, root, "post_install")).exitCode).toBe(0);
            expect((await hook(runtime, root, "pre_uninstall")).exitCode).toBe(0);
            expect(snapshot(source)).toBe("missing");
            expect(snapshot(second)).toBe("missing");
            expect(readFileSync(join(target, "keep.txt"), "utf8")).toBe("config-preserved");
            expect(readFileSync(join(root, "persist/local/keep.txt"), "utf8")).toBe("state-preserved");
        }, 30000);

        for (const kind of ["directory", "file", "foreign-link", "broken-link", "junction", "second-conflict", "persist-file", "persist-link", "acl-denied"]) {
            test(`reject ${kind} without changing either data location`, async () => {
                const { root, source, second, target } = fixture(`7-${kind}`, kind.startsWith("persist-") ? kind : "directory");
                if (kind === "directory") { mkdirSync(source); writeFileSync(join(source, "keep.txt"), "old-config"); }
                if (kind === "file") writeFileSync(source, "old-config");
                if (kind === "foreign-link" || kind === "junction") symlinkSync(join(root, "foreign"), source, kind === "junction" ? "junction" : "dir");
                if (kind === "broken-link") symlinkSync(join(root, "absent"), source, "dir");
                if (kind === "second-conflict") { symlinkSync(target, source, "dir"); mkdirSync(second); writeFileSync(join(second, "keep.txt"), "old-state"); }
                const paths = [source, second, target, join(root, "persist/local")];
                const before = paths.map(snapshot);
                const result = await hook(runtime, root, "pre_install", kind === "acl-denied");
                expect(result.exitCode).not.toBe(0);
                expect(paths.map(snapshot)).toEqual(before);
                expect(readFileSync(join(target, "keep.txt"), "utf8")).toBe("config-preserved");
                if (!kind.startsWith("persist-")) expect(readFileSync(join(root, "persist/local/keep.txt"), "utf8")).toBe("state-preserved");
                if (kind === "directory") expect(readFileSync(join(source, "keep.txt"), "utf8")).toBe("old-config");
                if (kind === "second-conflict") expect(readFileSync(join(second, "keep.txt"), "utf8")).toBe("old-state");
            }, 15000);
        }

        test("relative link to own persist survives mapping and uninstalls cleanly", async () => {
            const { root, source, target } = fixture(`${runtime === "pwsh" ? "7" : "5"}-relative-link`);
            symlinkSync(relative(join(root, "roaming"), target), source, "dir");
            expect((await hook(runtime, root, "pre_install")).exitCode).toBe(0);
            expect((await hook(runtime, root, "post_install")).exitCode).toBe(0);
            expect((await hook(runtime, root, "pre_uninstall")).exitCode).toBe(0);
            expect(snapshot(source)).toBe("missing");
            expect(readFileSync(join(target, "keep.txt"), "utf8")).toBe("config-preserved");
        }, 15000);

        test("entire persist parent can be absent on fresh install", async () => {
            const root = join(testRoot, "missing-persist-parent");
            mkdirSync(root);
            expect((await hook(runtime, root, "pre_install")).exitCode).toBe(0);
            expect((await hook(runtime, root, "post_install")).exitCode).toBe(0);
            expect(lstatSync(join(root, "roaming/herdr")).isSymbolicLink()).toBe(true);
            expect(lstatSync(join(root, "local/herdr")).isSymbolicLink()).toBe(true);
        }, 15000);

        for (const late of ["directory", "foreign-link"]) {
            test(`post_install rejects late ${late} before any mapping`, async () => {
                const { root, source, second } = fixture(`late-${late}`);
                expect((await hook(runtime, root, "pre_install")).exitCode).toBe(0);
                if (late === "directory") { mkdirSync(second); writeFileSync(join(second, "keep.txt"), "late-data"); }
                else symlinkSync(join(root, "foreign"), second, "dir");
                const original = snapshot(second);
                expect((await hook(runtime, root, "post_install")).exitCode).not.toBe(0);
                expect(snapshot(source)).toBe("missing");
                expect(snapshot(second)).toBe(original);
                if (late === "directory") expect(readFileSync(join(second, "keep.txt"), "utf8")).toBe("late-data");
            }, 15000);
        }

        for (const kind of ["directory", "foreign-link", "broken-link", "junction"]) {
            test(`uninstall preserves replaced ${kind} and first owned link`, async () => {
                const { root, source, second, target } = fixture(`uninstall-${kind}`);
                symlinkSync(target, source, "dir");
                if (kind === "directory") { mkdirSync(second); writeFileSync(join(second, "keep.txt"), "new-owner-data"); }
                else symlinkSync(join(root, kind === "broken-link" ? "absent" : "foreign"), second, kind === "junction" ? "junction" : "dir");
                const before = [snapshot(source), snapshot(second)];
                expect((await hook(runtime, root, "pre_uninstall")).exitCode).not.toBe(0);
                expect([snapshot(source), snapshot(second)]).toEqual(before);
                if (kind === "directory") expect(readFileSync(join(second, "keep.txt"), "utf8")).toBe("new-owner-data");
            }, 15000);
        }

        test("link creation failure is terminal under default Continue", async () => {
            const { root, source } = fixture("create-link-error");
            const result = await hook(runtime, root, "post_install", false, "create-link");
            expect(result.exitCode).not.toBe(0);
            expect(result.output).toContain("Injected link creation permission failure");
            expect(result.output).not.toContain("[Portable Mode] Linked");
            expect(snapshot(source)).toBe("missing");
        }, 15000);

        test("uninstall preserves an owned link when its target is missing", async () => {
            const root = join(testRoot, "uninstall-owned-broken");
            for (const dir of ["roaming", "local", "persist/roaming"]) mkdirSync(join(root, dir), { recursive: true });
            const first = join(root, "roaming/herdr"), second = join(root, "local/herdr");
            symlinkSync(join(root, "persist/roaming"), first, "dir");
            symlinkSync(join(root, "persist/local"), second, "dir");
            const before = [snapshot(first), snapshot(second)];
            expect((await hook(runtime, root, "pre_uninstall")).exitCode).not.toBe(0);
            expect([snapshot(first), snapshot(second)]).toEqual(before);
        }, 15000);

        test("link deletion failure is terminal and never reports success", async () => {
            const { root, source, target } = fixture("remove-link-error");
            symlinkSync(target, source, "dir");
            const original = snapshot(source);
            const result = await hook(runtime, root, "pre_uninstall", false, "remove-link");
            expect(result.exitCode).not.toBe(0);
            expect(result.output).toContain("Injected link removal permission failure");
            expect(result.output).not.toContain("Removed symbolic link");
            expect(snapshot(source)).toBe(original);
        }, 15000);
    });
}

test("Windows PowerShell 5.1 stops before mapping with an actionable prerequisite", async () => {
    const { root, source, second, target } = fixture("5-prerequisite");
    const result = await hook("C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe", root, "pre_install");
    expect(result.exitCode).not.toBe(0);
    expect(result.output).toContain("PowerShell 7");
    expect(snapshot(source)).toBe("missing");
    expect(snapshot(second)).toBe("missing");
    expect(readFileSync(join(target, "keep.txt"), "utf8")).toBe("config-preserved");
}, 15000);
