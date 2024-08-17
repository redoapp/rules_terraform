import { ConstructsMakerProviderTarget, Language } from "@cdktf/commons";
import { TerraformProviderGenerator } from "@cdktf/provider-generator/lib/get/generator/provider-generator";
import { CodeMaker } from "codemaker";
import { copyFile, mkdir, readdir, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

export async function provider({
  schemaPath,
  source,
  outputPath,
}: {
  schemaPath: string;
  source: string;
  outputPath: string;
}) {
  const name = source.replace(/.*\//, "");
  const schema = JSON.parse(await readFile(schemaPath, "utf-8"));
  const code = new CodeMaker();
  const generator = new TerraformProviderGenerator(code, schema);
  const target = new ConstructsMakerProviderTarget(
    { name, source, fqn: "" },
    Language.TYPESCRIPT,
  );
  generator.generate(target);
  const tmpPath = join(
    tmpdir(),
    `cdktf-provider-${Math.random().toString(36).substring(8)}`,
  );
  try {
    await code.save(tmpPath);
    await (async function copyTree(src: string, dest: string) {
      try {
        await mkdir(dest);
      } catch (e) {
        if (e.code !== "EEXIST") {
          throw e;
        }
      }
      for (const file of await readdir(src, { withFileTypes: true })) {
        if (file.isDirectory()) {
          await copyTree(join(src, file.name), join(dest, file.name));
        } else if (file.name.endsWith(".ts")) {
          await copyFile(join(src, file.name), join(dest, file.name));
        }
      }
    })(join(tmpPath, "providers", name), outputPath);
  } finally {
    await rm(tmpPath, { force: true, recursive: true });
  }
}
