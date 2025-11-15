import net.http
import json
import os

// Structs
struct Project {
  name      string
  version   string
  url      string
}

struct Registry {
  projects []Project
}

struct Ghpkg {
  name          string
  version       string
  description   string
  build         string
  binary_name   string
  dependencies  []string
  os            []string
}

struct Db {
mut:
  name        string
  binary_name string
  version     string
  description string
}

// Main function
fn main() {
    args := os.args
    if args.len < 2 {
    eprintln('No arguments provided')
    return
  }

  match true {
    args[1] == "-S" && args.len > 2 { install_package(args[2]) }
    args[1] == "-R" && args.len > 2 { remove_package(args[2]) }
    args[1] == "-Q" && args.len > 2 { search_packages(args[2]) }
    args[1] == "-L" { list_local() }
    args[1] == "-Lg" { list_global() }
    args[1] == "-U" { update() }
    args[1] == "-C" { check() }
    else {
      eprintln("Usage:")
      println("  -S <pkg>   install package")
      println("  -R <pkg>   remove package")
      println("  -Q <name>  search packages")
      println("  -L         list local packages")
      println("  -Lg        list global packages")
      println("  -U         update installed packages")
      println("  -C         check local database against installed binaries")
      return
    }
  }
}

// install_package function
fn install_package(pkg_name_imut string)
{
  // Take pkg_name_imut through function call and make it mutable
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

  // Join db_path together
  mut db_path := ''
  $if windows {
    db_path = os.join_path(os.getenv(APPDATA), ghpkg, "db.json")
  } $else {
    db_path = os.join_path("/etc", "ghpkg", "db.json")
  }
  println("DB path: $db_path")

  // Clone repo
  os.system("git clone $pkg_url ${os.join_path(pkg_path, pkg_name)}")

  // Parse .ghpkg file
  mut ghpkg_file := os.read_file("$pkg_path$pkg_name/.ghpkg") or {
    eprintln('Could not read file: $err')
    return
  }

  // Replace $temp with actual pkg_path directory
  ghpkg_file = ghpkg_file.replace("\$temp", pkg_path)

  // Decode ghpkg_file as ghpkg_json
  ghpkg_json := json.decode(Ghpkg, ghpkg_file) or {
    eprintln('Invalid JSON: $err')
    return
  }

  // Check OS compatibility
  current_os := os.user_os()
  mut supported := false
  for pkg_os in ghpkg_json.os {
    if pkg_os == current_os {
      supported = true break
    }
  }

  if !supported {
    eprintln("This package does not support your OS: $current_os")
    return
  }

  // Check dependencies
  for dep in ghpkg_json.dependencies {
    mut res := os.Result{} // Special type for a return value
    $if windows { res = os.execute("where $dep") } $else { res = os.execute("which $dep") }
    if res.exit_code != 0 {
      eprintln("Dependency '$dep' is missing")
    }
  }

  // Build
  println("Building...")
  os.system(ghpkg_json.build)

  // find binary PATHed location to move to
  mut bin_target := ''
  $if linux || macos {
    bin_target = '/usr/local/bin/' + pkg_name
  } $else $if windows {
    // Use a local Programs folder in %LOCALAPPDATA%
    local_appdata := os.getenv('LOCALAPPDATA')
    if local_appdata == '' {
      eprintln('Could not detect LOCALAPPDATA, using C:\\Temp')
      bin_target = 'C:\\Temp\\' + pkg_name + '.exe'
    } else {
      bin_target = os.join_path(local_appdata, 'ghpkg', 'bin', pkg_name + '.exe')
      // Ensure the folder exists
      os.mkdir_all(os.dir(bin_target)) or {
        eprintln('Failed to create target folder: $err')
        return
      }
    }
  }

  // Move or copy binary 
  $if linux || macos {
    os.system('sudo mv $pkg_path$pkg_name/${ghpkg_json.binary_name} $bin_target')
  } $else $if windows {
    os.system('copy "${pkg_path}${pkg_name}\\${pkg_name}.exe" "${bin_target}\\${pkg_name}.exe"')
  }
  println('Package built and moved to $bin_target')

  // Parse db.json as db_raw
  db_raw_in := os.read_file(db_path) or {
    eprintln("Could not find db: $err") 
    return
  }

  // Parse db.json as db_json
  mut db_json := json.decode([]Db, db_raw_in) or {
    eprintln("Could not decode JSON: $err")
    return
  }

  // Append name, version, and description from .ghpkg to db_json
  db_json << Db{
    name: ghpkg_json.name
    binary_name: ghpkg_json.binary_name
    version: ghpkg_json.version
    description: ghpkg_json.description
  }

  // Encode db_json as db_raw_out
  db_raw_out := json.encode_pretty(db_json)

  // Write db_raw_out to db_path
  os.write_file(db_path, db_raw_out) or {
    eprintln("Failed to write to DB: $err")
    return
  }
}

// remove_package function
fn remove_package(pkg_name_imut string)
{
  // Find binary location
  mut bin_target := ''
  $if linux || macos {
    bin_target = '/usr/local/bin/' + pkg_name_imut
  } $else $if windows {
    // Use a local Programs folder in %LOCALAPPDATA% 
    local_appdata := os.getenv('LOCALAPPDATA')
    if local_appdata == '' {
      eprintln('Could not detect LOCALAPPDATA, using C:\\Temp')
      bin_target = 'C:\\Temp\\' + pkg_name_imut + '.exe'
    } else {
      bin_target = os.join_path(local_appdata, 'ghpkg', 'bin', pkg_name_imut + '.exe')
      // Ensure the folder exists
      os.mkdir_all(os.dir(bin_target)) or {
        eprintln('Failed to create target folder: $err')
        return
      }
    }
  }

  // Join db_path together
  mut db_path := ''
  $if windows {
    db_path = os.join_path(os.getenv(APPDATA), ghpkg, "db.json")
  } $else {
    db_path = os.join_path("/etc", "ghpkg", "db.json")
  }
    println("DB path: $db_path")

  // Parse db.json as db_raw_in
  db_raw_in := os.read_file(db_path) or {
    eprintln("Could not open db.json: $err")
    return
  }

  // Parse db_raw_in as db_json
  mut db_json := json.decode([]Db, db_raw_in) or {
    eprintln("Failed to parse JSON: $err")
    return
  }

  // Search for pkg_name_imut in db_json
  db_json = db_json.filter(it.name != pkg_name_imut)

  // Encode db.json as db_raw_out
  db_raw_out := json.encode_pretty(db_json)

  // Save db.json
  os.write_file(db_path, db_raw_out) or {
    eprintln("Failed to save db.json: $err")
    return
  }

  println("Removed entry from db.json")

  // Remove binary
  os.system("rm ${bin_target}")
  println("Removed binary from ${bin_target}")
}

// Search locally
fn list_local()
{
  println("Listing all packages...")

  // Join db_path together
  mut db_path := ''
  $if windows {
    db_path = os.join_path(os.getenv(APPDATA), ghpkg, "db.json")
  } $else {
    db_path = os.join_path("/etc", "ghpkg", "db.json")
  }
  println("DB path: $db_path")

  // Parse db as db_raw
  db_raw := os.read_file(db_path) or {
    eprintln("Could not open db.json: $err")
    return
  }

  // Decode db_raw as db_json
  db_json := json.decode([]Db, db_raw) or {
    eprintln("Failed to decode JSON: $err")
    return
  }

  // List db_json
  for entry in db_json {
    println("${entry.name} ${entry.version} - ${entry.description}")
  }
}

fn list_global()
{
  println("Listing all packages...")

  // Import pkglist
  pkglist_url := "https://raw.githubusercontent.com/Frothy7650/ghpkgList/master/pkglist.json"
  pkglist_raw := http.get(pkglist_url) or {
    eprintln("Failed to fetch JSON: $err")
    return
  }

  // Decode pkglist_raw
  pkglist_json := json.decode(Registry, pkglist_raw.body) or {
    eprintln("Failed to fetch pkglist: $err")
    return
  }

  // List pkglist
  for project in pkglist_json.projects {
    println("${project.name} ${project.version} - ${project.url}")
  }
}

fn search_packages(pkg_name_imut string)
{
  println("Searching packages...")

  // Import pkglist 
  pkglist_url := "https://raw.githubusercontent.com/Frothy7650/ghpkgList/master/pkglist.json"
  pkglist_raw := http.get(pkglist_url) or {
    eprintln("Failed to fetch pkglist: $err")
    return
  }

  // Parse pkglist_raw as pkglist_json
  pkglist_json := json.decode(Registry, pkglist_raw.body) or {
    eprintln("Failed to decode pkglist: $err")
    return
  }

  // Search through the pkglist_json
  results := pkglist_json.projects.filter(it.name.contains(pkg_name_imut))

  if results.len == 0 {
    println("No packages found matching '${pkg_name_imut}'")
  }

  // Print it 
  for pkg in results {
    println("${pkg.name} ${pkg.version} - ${pkg.url}")
  }
}

// Update packages
fn update()
{
  // Import pkglist
  pkglist_url := "https://raw.githubusercontent.com/Frothy7650/ghpkgList/master/pkglist.json"
  pkglist_raw := http.get(pkglist_url) or {
    eprintln("Failed to fetch pkglist: $err")
    return
  }

  // Parse pkglist_raw as pkglist_json
  pkglist_json := json.decode(Registry, pkglist_raw.body) or {
    eprintln("Failed to decode pkglist: $err")
    return
  }

  // Join db_path together
  mut db_path := ''
  $if windows {
    db_path = os.join_path(os.getenv(APPDATA), ghpkg, "db.json")
  } $else {
    db_path = os.join_path("/etc", "ghpkg", "db.json")
  }
  println("DB path: $db_path")

  // Parse db as db_raw
  db_raw := os.read_file(db_path) or {
    eprintln("Could not open db.json: $err")
    return
  }

  // Decode db_raw as db_json
  db_json := json.decode([]Db, db_raw) or {
    eprintln("Failed to decode JSON: $err")
    return
  }

  // Search for updates
  for pkg in pkglist_json.projects {
    for dbpkg in db_json {
      if pkg.name == dbpkg.name && pkg.version != dbpkg.version {
        println('${pkg.name} version differs: ${dbpkg.version} -> ${pkg.version}')
      }
    }
  }
}

fn check()
{
  println("Checking binaries...")

  // Find binary location
  mut bin_location := ''
  $if linux || macos {
    bin_location = '/usr/local/bin/'
  } $else $if windows {
    // Use a local Programs folder in %LOCALAPPDATA% 
    local_appdata := os.getenv('LOCALAPPDATA')
    if local_appdata == '' {
      eprintln('Could not detect LOCALAPPDATA, using C:\\Temp')
      bin_location = 'C:\\Temp\\'
    } else {
      bin_target = os.join_path(local_appdata, 'ghpkg', 'bin')
      // Ensure the folder exists
      os.mkdir_all(os.dir(bin_location)) or {
        eprintln('Failed to create target folder: $err')
        return
      }
    }
  }

  // Join db_path together
  mut db_path := ''
  $if windows {
    db_path = os.join_path(os.getenv(APPDATA), ghpkg, "db.json")
  } $else {
    db_path = os.join_path("/etc", "ghpkg", "db.json")
  }
  println("DB path: $db_path")

  // Parse db as db_raw
  db_raw_in := os.read_file(db_path) or {
    eprintln("Could not open db.json: $err")
    return
  }

  // Parse db_raw as db_json
  mut db_json := json.decode([]Db, db_raw_in) or {
    eprintln("Failed to decode JSON: $err")
    return
  }

  // Iterate over db_json and remove entries with missing binaries
  mut updated_db := []Db{}  // new list to hold entries that exist

  for pkg in db_json {
    // Determine expected binary path
    mut bin_path := ''
    $if linux || macos {
      bin_path = os.join_path(bin_location, pkg.binary_name)
    } $else $if windows {
      bin_path = os.join_path(bin_location, pkg.binary_name + '.exe')
    }

    // Check if binary exists
    if os.exists(bin_path) {
      updated_db << pkg  // keep this entry
      println("${pkg.name}: binary exists at $bin_path")
    } else {
      println("${pkg.name}: binary missing at $bin_path, removing from db.json")
    }
  }

  // Save updated list back to db.json
  db_raw_out := json.encode_pretty(updated_db)
  os.write_file(db_path, db_raw_out) or {
    eprintln("Failed to update db.json: $err")
    return
  }
}
