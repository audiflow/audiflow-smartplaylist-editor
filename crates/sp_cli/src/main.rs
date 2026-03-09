mod cmd_format;
mod cmd_serve;
mod cmd_validate;

use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(
    name = "audiflow-editor",
    about = "Smart playlist editor and config tools"
)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Start the web editor server
    Serve {
        /// Path to data directory (must contain patterns/meta.json)
        #[arg(long, default_value = ".")]
        data_dir: String,
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
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();

    let exit_code = match cli.command {
        Commands::Serve {
            data_dir,
            port,
            static_dir,
        } => match cmd_serve::run(&data_dir, port, static_dir.as_deref()).await {
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
    };

    std::process::exit(exit_code);
}
