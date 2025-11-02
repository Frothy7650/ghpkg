import net.http
import json
import os

// -- Structs --
struct Project {
  name string
  url  string
}

struct Registry {
  projects []Project
}

struct Ghpkg {
  name          string
  version       string
  description   string
  build         string
  dependencies  []string
  os            []string
}

struct Db {
  name        string
  version     string
  description string
}

// -- Main function --
fn main()
{
  args := os.args
  if args.len < 2 {
    eprintln('No arguments provided')
    return
  }

  // Check for -S flag
  for i, arg in args {
    if arg == '-S' && i + 1 < args.len {
      install_package(args[i+1])
      return
    }
  }

  eprintln('No valid flag provided')
}

// -- install_package function
fn install_package(pkg_name_imut string)
{
  mut pkg_name := pkg_name_imut
  println("Installing package $pkg_name")

  // Import pkglist
  pkglist_url := "https://raw.githubusercontent.com/Frothy7650/ghpkgList/master/pkglist.json"
  pkglist_text := http.get(pkglist_url) or {
    eprintln("Failed to fetch JSON: $err")
    return
  }

  // Parse as JSON
  registry := json.decode(Registry, pkglist_text.body) or {
    eprintln('Failed to parse JSON: $err')
    return
  }

  // Search registry for pkg_name
  mut pkg_exists := false
  mut pkg_url := ''
  for project in registry.projects {
    if project.name.to_lower() == pkg_name.to_lower() {
      println('Found package: $project.name')
      println('URL: $project.url')
      pkg_name = project.name
      pkg_url = project.url
      pkg_exists = true
      break
    }
  }

  if !pkg_exists {
    println('Package "$pkg_name" not found in registry')
    return
  }

  // Determine paths
  mut pkg_path := ''
  $if windows {
    pkg_path = os.join_path(os.temp_dir(), 'ghpkg')
  } $else $if linux {
    pkg_path = '/tmp/'
  } $else $if macos {
    pkg_path = '/tmp/'
  } $else {
    eprintln("Error: OS not supported")
    return
  }

  mut db_path := ''
  $if windows {
    db_path = os.getenv('APPDATA') + '\\ghpkg\\db.json'
  } $else $if linux {
    db_path = os.getenv('HOME') + '/.config/ghpkg/db.json'
  } $else $if macos {
    db_path = os.getenv('HOME') + '/.config/ghpkg/db.json'
  } $else {
    eprintln('OS not supported')
  }

  db_path = if db_path.starts_with('~') {
    os.getenv('HOME') + db_path[1..]
  } else {
    db_path
  }

  // Clone repo
  os.system("git clone $pkg_url $pkg_path$pkg_name")

  // Parse .ghpkg file
  ghpkg_file := os.read_file("$pkg_path$pkg_name/.ghpkg") or {
    eprintln('Could not read file: $err')
    return
  }

  ghpkg_json := json.decode(Ghpkg, ghpkg_file) or {
    eprintln('Invalid JSON: $err')
    return
  }

  // Check OS compatibility
  current_os := os.user_os()
  mut supported := false
  for pkg_os in ghpkg_json.os {
    if pkg_os == current_os {
      supported = true
      break
    }
  }

  if !supported {
    eprintln("This package does not support your OS: $current_os")
    return
  }

  // Check dependencies
  for dep in ghpkg_json.dependencies {
    res := os.execute("which $dep")
    if res.exit_code != 0 {
      eprintln("Dependency '$dep' is missing")
    }
  }

  // Build
  println("Building...")
  os.system(ghpkg_json.build)

  // Move binary to /usr/local/bin/
  os.system("sudo mv $pkg_path$pkg_name/$pkg_name /usr/local/bin/$pkg_name")
  println("Package built and moved to /usr/local/bin/")

  // Parse db.json as db_raw
  db_raw_in := os.read_file(db_path) or {
    eprintln("Could not find db: $err")
    return
  }

  // Parse db.json as db_json
  mut db_json := json.decode(Db, db_raw) or {
    eprintln("Could not decode JSON: $err")
    return
  }

  db_json.name = "BCB"
  db_json.version = "1.0.0"
  db_json.description = "Basic ChatBot"

  db_raw_out := json.encode(db_json)

  os.write_file(db_path, db_raw_out) or {
    eprintln("Failed to write to DB: $err")
    return
  }
}

// -- remove_package function --
