Maintainer: Evan Church frothycurve@gmail.com
pkgname=ghpkg
pkgver=1.0.0
pkgrel=1
pkgdesc="An indev package manager, using github repos, to build from source."
arch=('any')
url="https://github.com/user/ghpkg"
license=('MIT')
depends=('git')
source=("$pkgname-$pkgver.tar.gz::https://github.com/user/ghpkg/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('SKIP') # optional, for testing use 'SKIP'

build() {
  cd "$srcdir/$pkgname-$pkgver"
  make linux
}

package() {
  cd "$srcdir/$pkgname-$pkgver"
  # install files, e.g.,
  install -Dm755 ghpkg "$pkgdir/usr/bin/ghpkg"
  install -Dm644 db.json "$pkgdir/etc/ghpkg/db.json"
}

