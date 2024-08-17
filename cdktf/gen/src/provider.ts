import {CodeMaker} from "codemaker";
import { tmpdir } from "node:os";
import { rm, rename, readdir, unlink } from "node:fs/promises";
import { join } from "node:path";
import { TerraformProviderGenerator } from "@cdktf/provider-generator/lib/get/generator/provider-generator";
import { ConstructsMakerProviderTarget, Language } from "@cdktf/commons";
import { readFile } from "node:fs/promises";

export async function provider({ schemaPath, source, outputPath }: { schemaPath: string, source: string, outputPath: string }): Promise<void> {
    const name = source.replace(/.*\//, "");
    const schema = JSON.parse(await readFile(schemaPath, 'utf-8'));
    const code = new CodeMaker();
    const generator = new TerraformProviderGenerator(code, schema);
    const target=  new ConstructsMakerProviderTarget({ name, source, fqn: ""  }, Language.TYPESCRIPT );
    generator.generate(target);
    const tmpPath = join(tmpdir(), `cdktf-provider-${Math.random().toString(36).substring(8)}`);
    try {
        await code.save(tmpPath);
        await rename(join(tmpPath, "providers", name), outputPath);
        (async function clean(path: string) {
            for (const file of await readdir(path, { withFileTypes: true })) {
                if (file.isDirectory()) {
                    await clean(join(path, file.name));
                } else if (!file.name.endsWith(".ts")) {
                    await unlink(join(path, file.name));
                }
            }
        })(outputPath);
    } finally {
        await rm(tmpPath, { force: true, recursive: true });
    }
}
