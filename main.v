import net.http
import json
import os

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

fn main()
{
  // Arg handling
  args := os.args
  mut pkg_name := ''

  // Get pkgname/s
  for i, arg in args {
    if arg == '-S' && i + 1 < args.len {
      pkg_name = args[i+1]
    }
  }

  // Handle no pkg specified
  if pkg_name == '' {
    eprintln('No package specified')
    return
  }
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

  // Handle pkg_exists
  if !pkg_exists {
    println('Package "$pkg_name" not found in registry')
    return
  }

  // Check OS
  mut pkg_path := ''
  $if windows {
    pkg_path = os.join_path(os.temp_dir(), 'ghpkg')
  } $else $if linux {
    pkg_path = '/tmp/'
  } $else $if macos {
    pkg_path = '/tmp/'
  } $else {
    eprintln("Error: OS not supported")
  }
  mut db_path := ''
  $if windows {
    db_path = ''
  } $else $if linux {
    db_path = "~/.config/ghpkg/db.json"
  } $else $if macos {
    db_path = "~/.config/ghpkg/db.json"
  } $else {
    eprintln("Error: OS not supported")
  }
  db_path = if db_path.starts_with('~') {
    os.getenv('HOME') + db_path[1..]
  } else {
    db_path
  }

  // Clone repo
  os.system("git clone $pkg_url $pkg_path$pkg_name")

  // Parse .ghpkg into string
  ghpkg_file := os.read_file("/tmp/BCB/.ghpkg") or {
    eprintln('Could not read file: $err')
    return
  }

  // Decode .ghpkg as JSON
  ghpkg_json := json.decode(Ghpkg, ghpkg_file) or {
    eprintln('Invalid JSON: $err')
    return
  }
  // Check .ghpkg OS
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

  // Check .ghpkg dependencies
  for dep in ghpkg_json.dependencies {
    res := os.execute("which $dep")
    if res.exit_code != 0 {
      eprintln("Dependency '$dep' is missing")
    }
  }

  // Parse db.json as string
  db_text := os.read_file(db_path) or {
    eprintln("Invalid db: $err")
    return
  }

  // Decode db.json as JSON
  db_json := json.decode(Db, db_text) or {
    eprintln("Invalid DB: $err")
    return
  }

  println("Building...")
  os.system(ghpkg_json.build)
}
