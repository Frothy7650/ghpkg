import net.http
import json
import os

// Structs
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
mut:
  name        string
  version     string
  description string
}

// Main function
fn main()
{
  // Get args and exit if args < 2
  args := os.args
  if args.len < 2 {
    eprintln('No arguments provided')
    return
  }

  // Check for -S flag
  match true {
    args[1] == "-S" { install_package(args[2]) }
    args[1] == "-R" { remove_package(args[2]) }
    else {
      eprintln("No valid flag found, exiting...")
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

  // Do not ever touch this
  mut user_home := ''
  $if linux || macos {
    sudo_user := os.getenv('SUDO_USER')
    if sudo_user != '' {
      user_home = '/home/' + sudo_user
    } else {
      user_home = os.getenv('HOME')
    }
  } $else $if windows {
    user_home = os.getenv('APPDATA')
    if user_home == '' {
      // fallback to default Windows profile
      user_home = 'C:\\Users\\Default'
    }
  }

  // Join db_path together
  mut db_path := os.join_path(user_home, ".config", "ghpkg", "db.json")
  println("DB path: $db_path")
  db_path = if db_path.starts_with('~') {
    os.getenv('HOME') + db_path[1..]
  } else {
    db_path
  }

  // Clone repo
  os.system("git clone $pkg_url ${os.join_path(pkg_path, pkg_name)}")

  // Parse .ghpkg file
  ghpkg_file := os.read_file("$pkg_path$pkg_name/.ghpkg") or {
    eprintln('Could not read file: $err')
    return
  }

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
    res := os.execute("which $dep")
    if res.exit_code != 0 {
      eprintln("Dependency '$dep' is missing")
    }
  }

  // Build
  println("Building...")
  os.system(ghpkg_json.build)

  // Move binary to PATHed location
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
    os.system('sudo mv $pkg_path$pkg_name/$pkg_name $bin_target')
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
  // Do not ever touch this
  mut user_home := ''
  $if linux || macos {
    sudo_user := os.getenv('SUDO_USER')
    if sudo_user != '' {
      user_home = '/home/' + sudo_user
    } else {
      user_home = os.getenv('HOME')
    }
  } $else $if windows {
    user_home = os.getenv('APPDATA')
    if user_home == '' {
      // fallback to default Windows profile
      user_home = 'C:\\Users\\Default'
    }
  }

  // Find binary location
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

  // Find db.json
  db_path := os.join_path(user_home, ".config", "ghpkg", "db.json")

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
