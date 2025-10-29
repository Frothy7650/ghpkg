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
  name        string
  version     string
  description string
  repo        string
  language    string
  os          []string
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
    pkg_path = '/tmp/'
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
  // Check .ghpkg
  println(os.user_os())
}
