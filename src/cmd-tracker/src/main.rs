use std::env;
use std::fs::{self, OpenOptions};
use std::io::{self, Write};
use std::process::{self, Command};
use std::time::Instant;

const USAGE_DIR: &str = ".cache/ainish-coder";
const USAGE_FILE: &str = "usage.csv";
const HEADER: &str = "timestamp,tool,subcommand,provider,exit_code,duration_ms,interactive,arg_count\n";

fn csv_escape(s: &str) -> String {
    if s.contains(',') || s.contains('"') || s.contains('\n') {
        format!("\"{}\"", s.replace('"', "\"\""))
    } else {
        s.to_string()
    }
}

fn usage_path() -> Option<std::path::PathBuf> {
    let home = env::var_os("HOME")?;
    let dir = std::path::Path::new(&home).join(USAGE_DIR);
    Some(dir.join(USAGE_FILE))
}

fn ensure_csv(path: &std::path::Path) -> io::Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    if path.exists() {
        // Check header matches — if schema changed, move old file to .bak and start fresh
        if let Ok(existing) = fs::read_to_string(path) {
            if let Some(first_line) = existing.lines().next() {
                if first_line != HEADER.trim_end() {
                    let bak = path.with_extension("csv.bak");
                    let _ = fs::copy(path, &bak);
                    let _ = fs::remove_file(path);
                }
            }
        }
    }
    if !path.exists() {
        let mut f = fs::File::create(path)?;
        f.write_all(HEADER.as_bytes())?;
    }
    Ok(())
}

fn append_row(path: &std::path::Path, row: &str) {
    match OpenOptions::new().create(true).append(true).open(path) {
        Ok(mut f) => {
            let _ = f.write_all(row.as_bytes());
        }
        Err(e) => {
            eprintln!("cmd-tracker: failed to write usage row: {e}");
        }
    }
}

fn is_interactive() -> bool {
    !env::var("AINISH_NON_INTERACTIVE").map_or(false, |v| v == "true")
}

/// Skip past our metadata args to find "--" and run the command directly.
/// Used when tracking is disabled — avoids overhead.
fn passthrough(args: &[String]) -> ! {
    let pos = args.iter().position(|a| a == "--").unwrap_or(args.len());
    let cmd_args: Vec<&str> = if pos < args.len() {
        args.iter().skip(pos + 1).map(|s| s.as_str()).collect()
    } else {
        args.iter().map(|s| s.as_str()).collect()
    };
    if cmd_args.is_empty() {
        eprintln!("cmd-tracker: no command to run");
        process::exit(1);
    }
    let status = Command::new(cmd_args[0])
        .args(&cmd_args[1..])
        .status()
        .unwrap_or_else(|e| {
            eprintln!("cmd-tracker: failed to spawn {}: {e}", cmd_args[0]);
            process::exit(127);
        });
    process::exit(status.code().unwrap_or(1));
}

fn main() {
    let args: Vec<String> = env::args().collect();

    // Usage: cmd-tracker <tool> <subcommand> <provider> -- <command...>
    //   tool       = "ainish-coder" | "pi" | "mini"
    //   subcommand = "--skills" | "--rules" | "" | skill name | etc.
    //   provider   = "openrouter" | "zai" | "" | etc.
    // Everything after "--" is the actual command to execute.

    if args.len() < 5 {
        eprintln!("Usage: cmd-tracker <tool> <subcommand> <provider> -- <command...>");
        process::exit(1);
    }

    if env::var("AINISH_NO_TRACKING").map_or(false, |v| v == "true") {
        passthrough(&args);
    }

    let tool = &args[1];
    let subcommand = &args[2];
    let provider = &args[3];

    // Find the "--" separator
    let dash_pos = args.iter().position(|a| a == "--");
    let cmd_args: Vec<&str> = match dash_pos {
        Some(pos) => args.iter().skip(pos + 1).map(|s| s.as_str()).collect(),
        None => {
            eprintln!("cmd-tracker: expected '--' separator before command");
            process::exit(1);
        }
    };

    if cmd_args.is_empty() {
        eprintln!("cmd-tracker: no command after '--'");
        process::exit(1);
    }

    let interactive = is_interactive();
    let arg_count = cmd_args.len().saturating_sub(1); // subtract the binary name
    let start = Instant::now();

    let status = Command::new(cmd_args[0])
        .args(&cmd_args[1..])
        .status()
        .unwrap_or_else(|e| {
            eprintln!("cmd-tracker: failed to spawn {}: {e}", cmd_args[0]);
            process::exit(127);
        });

    let duration_ms = start.elapsed().as_millis();
    let exit_code = status.code().unwrap_or(-1);

    if let Some(path) = usage_path() {
        if ensure_csv(&path).is_ok() {
            let timestamp = chrono_lite();
            let row = format!(
                "{},{},{},{},{},{},{},{}\n",
                csv_escape(&timestamp),
                csv_escape(tool),
                csv_escape(subcommand),
                csv_escape(provider),
                exit_code,
                duration_ms,
                interactive,
                arg_count,
            );
            append_row(&path, &row);
        }
    }

    process::exit(exit_code);
}

/// Minimal UTC timestamp — no chrono dependency.
fn chrono_lite() -> String {
    use std::time::SystemTime;
    let dur = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap_or_default();
    let secs = dur.as_secs();
    let (y, mo, d, h, min, s) = unix_to_utc(secs);
    format!("{y:04}-{mo:02}-{d:02}T{h:02}:{min:02}:{s:02}Z")
}

fn unix_to_utc(ts: u64) -> (u64, u64, u64, u64, u64, u64) {
    let mut days = ts / 86400;
    let sec_of_day = ts % 86400;
    let h = sec_of_day / 3600;
    let min = (sec_of_day % 3600) / 60;
    let s = sec_of_day % 60;

    days += 719468;
    let era = days / 146097;
    let doe = days - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let mo = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if mo <= 2 { y + 1 } else { y };

    (y, mo, d, h, min, s)
}
