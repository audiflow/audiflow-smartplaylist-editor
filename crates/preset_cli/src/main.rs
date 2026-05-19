mod cmd_bump_versions;
mod cmd_format;
mod cmd_serve;
mod cmd_validate;
mod config_walker;

use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(
    name = "audiflow-editor",
    about = "Preset editor and config tools for audiflow"
)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Start the web editor server
    Serve {
        /// Path to data directory (must contain presets/meta.json or legacy patterns/meta.json)
        #[arg(long, default_value = ".")]
        data_dir: String,
        /// Host address to bind to (use 0.0.0.0 for Docker/LAN access)
        #[arg(long, default_value = "127.0.0.1")]
        host: String,
        /// Port to listen on
        #[arg(long, default_value = "8080")]
        port: u16,
        /// Serve static files from this directory instead of embedded assets
        #[arg(long)]
        static_dir: Option<String>,
    },
    /// Validate config files against JSON schema
    Validate {
        /// Path to data directory
        #[arg(long, default_value = ".")]
        data_dir: String,
        /// Specific files to validate (validates all if omitted)
        files: Vec<String>,
    },
    /// Format config JSON files
    Format {
        /// Path to data directory
        #[arg(long, default_value = ".")]
        data_dir: String,
        /// Check formatting without writing (exit 1 if any would change)
        #[arg(long)]
        check: bool,
        /// Specific files to format (formats all if omitted)
        files: Vec<String>,
    },
    /// Bump dataVersion fields for changed presets (CI use). Auto-detects
    /// presets/ then legacy patterns/ in the current directory when neither
    /// --presets-dir nor --patterns-dir is given.
    BumpVersions {
        /// Path to presets directory (v7). Takes precedence over --patterns-dir.
        #[arg(long)]
        presets_dir: Option<String>,
        /// Legacy alias for --presets-dir (v6 layout).
        #[arg(long)]
        patterns_dir: Option<String>,
        /// Git ref for previous state (e.g. HEAD~1)
        previous_ref: String,
        /// Output as JSON
        #[arg(long)]
        json: bool,
    },
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();

    let exit_code = match cli.command {
        Commands::Serve {
            data_dir,
            host,
            port,
            static_dir,
        } => match cmd_serve::run(&data_dir, &host, port, static_dir.as_deref()).await {
            Ok(()) => 0,
            Err(e) => {
                eprintln!("Error: {e}");
                1
            }
        },
        Commands::Validate { data_dir, files } => match cmd_validate::run(&data_dir, &files) {
            Ok(code) => code,
            Err(e) => {
                eprintln!("Error: {e}");
                1
            }
        },
        Commands::Format {
            data_dir,
            check,
            files,
        } => match cmd_format::run(&data_dir, check, &files) {
            Ok(code) => code,
            Err(e) => {
                eprintln!("Error: {e}");
                1
            }
        },
        Commands::BumpVersions {
            presets_dir,
            patterns_dir,
            previous_ref,
            json,
        } => {
            let dir = presets_dir.as_deref().or(patterns_dir.as_deref());
            match cmd_bump_versions::run(dir, &previous_ref, json) {
                Ok(code) => code,
                Err(e) => {
                    eprintln!("Error: {e}");
                    1
                }
            }
        }
    };

    std::process::exit(exit_code);
}
