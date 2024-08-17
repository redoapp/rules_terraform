import { ArgumentParser } from 'argparse';

type Args = ProviderArgs;

interface ProviderArgs {
    command: "provider";
    source: string;
    schema: string;
    output: string;
}

(async () => {
    const parser = new ArgumentParser({ prog: "cdktf-gen" });

    const subparsers = parser.add_subparsers({ dest: "command" });

    const providerParser = subparsers.add_parser("provider");
    providerParser.add_argument("--source", { required: true });
    providerParser.add_argument("schema");
    providerParser.add_argument("output");

    const args: Args = parser.parse_args();
    switch (args.command) {
        case 'provider': {
            const { provider } = await import('./provider');
            await provider({ source: args.source, schemaPath: args.schema, outputPath: args.output});
            break;
        }
    }
})().catch(e => {
    console.error(String(e?.stack ?? e));
    process.exit(1);
});
