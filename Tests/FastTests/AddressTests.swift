import Foundation
import Testing
@testable import Fast

// What the field makes of words typed without a scheme: a place, over http
// or https, or a search.
struct AddressTests {
    static func url(_ typed: String) -> String? { Address.url(from: typed)?.absoluteString }

    @Test func hostsWithPortsGoThere() {
        #expect(Self.url("192.168.1.1:8080") == "http://192.168.1.1:8080")
        #expect(Self.url("192.168.1.1:8080/admin") == "http://192.168.1.1:8080/admin")
        #expect(Self.url("localhost:3000") == "http://localhost:3000")
        #expect(Self.url("localhost:3000/api?x=1") == "http://localhost:3000/api?x=1")
        #expect(Self.url("LOCALHOST:3000") == "http://LOCALHOST:3000")
        #expect(Self.url("127.0.0.1:5000") == "http://127.0.0.1:5000")
        #expect(Self.url("0.0.0.0:8000") == "http://0.0.0.0:8000")
        #expect(Self.url("app.localhost:3000") == "http://app.localhost:3000")
        #expect(Self.url("example.com:8443") == "https://example.com:8443")
    }

    @Test func theLocalNetworkIsHttp() {
        #expect(Self.url("10.0.0.1") == "http://10.0.0.1")
        #expect(Self.url("172.16.0.5:8080") == "http://172.16.0.5:8080")
        #expect(Self.url("172.31.255.1") == "http://172.31.255.1")
        #expect(Self.url("172.32.0.5:8080") == "https://172.32.0.5:8080")
        #expect(Self.url("169.254.1.1") == "http://169.254.1.1")
        #expect(Self.url("router.local") == "http://router.local")
        #expect(Self.url("nas.local:5000") == "http://nas.local:5000")
        #expect(Self.url("10.com") == "https://10.com")
        #expect(Self.url("8.8.8.8") == "https://8.8.8.8")
    }

    @Test func tailscaleServersUseHttpUnlessASchemeWasSpecified() {
        #expect(Self.url("box:8080") == "http://box:8080")
        #expect(Self.url("box.tail1234.ts.net") == "http://box.tail1234.ts.net")
        #expect(Self.url("BOX.TAIL1234.TS.NET:8080/path") == "http://BOX.TAIL1234.TS.NET:8080/path")
        #expect(Self.url("100.64.0.0:8080") == "http://100.64.0.0:8080")
        #expect(Self.url("100.127.255.255") == "http://100.127.255.255")
        #expect(Self.url("100.63.255.255") == "https://100.63.255.255")
        #expect(Self.url("100.128.0.0") == "https://100.128.0.0")
        #expect(Self.url("ts.net") == "https://ts.net")
        #expect(Self.url("fake-ts.net") == "https://fake-ts.net")
        #expect(Self.url("https://box.tail1234.ts.net") == "https://box.tail1234.ts.net")
        #expect(Self.url("http://box.tail1234.ts.net") == "http://box.tail1234.ts.net")
    }

    @Test func ipv6InBrackets() {
        #expect(Self.url("[::1]:3000") == "http://[::1]:3000")
        #expect(Self.url("[::1]") == "http://[::1]")
        #expect(Self.url("[fe80::1]:80") == "http://[fe80::1]:80")
        #expect(Self.url("[febf::1]") == "http://[febf::1]")
        #expect(Self.url("[fd12:3456::1]") == "http://[fd12:3456::1]")
        #expect(Self.url("[fc00::1]") == "http://[fc00::1]")
        #expect(Self.url("[fec0::1]") == "https://[fec0::1]")
        #expect(Self.url("[2001:db8::1]:443/x") == "https://[2001:db8::1]:443/x")
        #expect(Self.url("[zz]:80") == nil)
    }

    @Test func aBareNameNeedsAServersPort() {
        #expect(Self.url("nas:5000") == "http://nas:5000")
        #expect(Self.url("myhost:8080") == "http://myhost:8080")
        #expect(Self.url("redis:6379") == "http://redis:6379")
        #expect(Self.url("printer:80") == "http://printer:80")
        #expect(Self.url("box:443") == "http://box:443")
        #expect(Address.isBareName("nas:5000"))
        #expect(!Address.isBareName("localhost:3000"))
        #expect(!Address.isBareName("192.168.1.1:8080"))
        #expect(!Address.isBareName("example.com"))
    }

    @Test func wordsWithANumberAreSearches() {
        for typed in ["note:3", "node:18", "redis:7", "re:5", "ps5:2", "x:1", "john:316", "8080:80"] {
            #expect(Self.url(typed) == nil, "\(typed)")
        }
    }

    @Test func schemeNamesAreNeverMachines() {
        for typed in ["tel:911", "tel:5551234", "javascript:1", "javascript:1024", "http:80", "https:8080",
                      "mailto:2000", "sms:5000", "file:1025", "yab:3000"] {
            #expect(Self.url(typed) == nil, "\(typed)")
        }
    }

    @Test func pathsOnThisMacAreFiles() {
        #expect(Self.url("/Users/me/site/dist/index.html") == "file:///Users/me/site/dist/index.html")
        #expect(Self.url("  /Users/me/My Site/a b.html ") == "file:///Users/me/My%20Site/a%20b.html")
        #expect(Self.url("/Users/me/site/../x.html") == "file:///Users/me/x.html")
        let home = FileManager.default.homeDirectoryForCurrentUser
        #expect(Address.url(from: "~/x.html")?.path == home.appendingPathComponent("x.html").path)
        #expect(Address.url(from: "~")?.path == home.standardizedFileURL.path)
        #expect(!Address.isBareName("/Users/me/x.html"))
        #expect(Self.url("//example.com") == nil)
        #expect(Self.url("~me") == nil)
    }

    @Test func notPlaces() {
        for typed in ["nas:", "nas:0", "nas:70000", "192.168.1.1:abc", "user@example.com", "todo", "hello world",
                      "1.2", "v1.2.3", "mailto:x@y.z"] {
            #expect(Self.url(typed) == nil, "\(typed)")
        }
    }

    @Test func schemesAreTakenAtTheirWord() {
        #expect(Self.url("http://a.b") == "http://a.b")
        #expect(Self.url("about:blank") == "about:blank")
        #expect(Self.url("github.com/sam") == "https://github.com/sam")
    }

    /// A "://" further on, in the path or the query, is the address's own,
    /// not its scheme: the Wayback Machine's pages, a sign-in's way back.
    @Test func anAddressInsideAnAddressIsStillAPlace() throws {
        #expect(Self.url("web.archive.org/web/2024/https://example.com/") == "https://web.archive.org/web/2024/https://example.com/")
        #expect(Self.url("example.com/login?next=https://example.com/home") == "https://example.com/login?next=https://example.com/home")
        #expect(Self.url("localhost:3000/callback?to=http://localhost:3000/") == "http://localhost:3000/callback?to=http://localhost:3000/")
        #expect(Self.url("example.com/a#https://b.example") == "https://example.com/a#https://b.example")
        // ⌘L's address, edited, is still the page it was.
        let page = try #require(URL(string: "https://web.archive.org/web/2024/https://example.com/"))
        let edited = Address.whole(page).replacingOccurrences(of: "2024", with: "2023")
        #expect(Self.url(edited) == "https://web.archive.org/web/2023/https://example.com/")
        // A scheme Yab doesn't show is still refused, and one it does is taken.
        #expect(Self.url("mailto://x") == nil)
        #expect(Self.url("http://a.b/?u=https://c.d") == "http://a.b/?u=https://c.d")
    }

    @Test func editableAddressesKeepWWWWhenTheirPathIsChanged() throws {
        for host in ["www.portaldasfinancas.gov.pt", "www.example.com:8443"] {
            let original = try #require(URL(string: "https://\(host)/old?x=1#part"))
            let editable = Address.whole(original)
            #expect(editable == "\(host)/old?x=1#part")
            let changed = editable.replacingOccurrences(of: "/old", with: "/new")
            let destination = try #require(Address.url(from: changed))
            #expect(destination.absoluteString == "https://\(host)/new?x=1#part")
        }
    }

    @Test func editableHostsDoNotChangeDisplayKeysOrBareHostInput() throws {
        let www = try #require(URL(string: "https://www.example.com:8443/old?x=1#part"))
        #expect(Address.pretty(www) == "example.com/old")
        #expect(Address.pretty(www, port: true) == "example.com:8443/old")
        #expect(Address.url(from: "www.example.com/old")?.host() == "www.example.com")
        let bare = try #require(URL(string: "https://example.com:8443/old?x=1#part"))
        #expect(Address.whole(bare) == "example.com:8443/old?x=1#part")
        #expect(Address.url(from: "example.com/old")?.host() == "example.com")
        #expect(Address.whole(URL(string: "about:blank")!) == "about:blank")
    }

    @Test func thePortStaysInTheFieldNotInHistory() {
        let url = URL(string: "http://localhost:3000/app?x=1")!
        #expect(Address.pretty(url) == "localhost/app")
        #expect(Address.pretty(url, port: true) == "localhost:3000/app")
        #expect(Address.whole(url) == "localhost:3000/app?x=1")
        #expect(Address.whole(URL(string: "http://[::1]:3000/")!) == "[::1]:3000")
        #expect(Address.pretty(URL(string: "http://[::1]/")!) == "[::1]")
    }

    /// A tab's row says a site's address beside its name; Yab's own pages
    /// have none (yab://mail read "mail mail"), mail says its account.
    @MainActor @Test func yabsOwnPagesSayNoAddress() {
        #expect(Tab.place(URL(string: "https://www.example.com/docs")!) == "example.com/docs")
        #expect(Tab.place(URL(string: "yab://task/1F2E")!) == "")
        #expect(Tab.place(URL(string: "yab://you")!) == "")
        #expect(Tab.ownIcon(URL(string: "https://example.com")!) == nil)
    }
}
