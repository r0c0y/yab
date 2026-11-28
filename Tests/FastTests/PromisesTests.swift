import Foundation
import Testing
@testable import Fast
@testable import MailCore

// Promises in Now (docs/promises.md): strict on the way in (a corpus of
// sentences that are and aren't promises, the hard ones among them), the
// day read right, a row only in its window, at most one in the field's two
// rows, and the budget that keeps them from nagging.
struct PromisesTests {
    /// A Wednesday at 10:00.
    static let wednesday = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 10))!

    // MARK: - the corpus

    /// Sentences of yours that promise something to someone.
    static let promises = [
        "I'll send you the deck by Friday.", "I will share the Q3 numbers tomorrow.", "Will intro you to Kenji this week.",
        "I'll get you the contract by Monday.", "I'm going to send the recording tonight.", "I'll forward the invoice today.",
        "Sure, I'll send them by Friday once the close is done.", "I'll review the PR before noon.", "Will send the slides after lunch.",
        "Let me check with the team and follow up.", "I'll fix the onboarding bug by Thursday.", "Will update the doc by EOD.",
        "I'll write up the brief today.", "We'll send the proposal next week.", "You'll have the numbers by Friday.",
        "I'll introduce you to Dana tomorrow.", "Happy to help, I'll send the logo files tomorrow morning.",
        "I'll share the link in a bit.", "Will get back to you on pricing by Tuesday.", "I'll send over the signed contract on Monday.",
        "Let me send you the notes from the call.", "I'll put you in touch with our CTO.", "I will finish the mockups by 3pm.",
        "Will forward Mark's email shortly.", "I'll update the estimate and send it over.", "I'll loop in Ana on this thread.",
        "Let me dig up the old design and send it.", "I'll draft the announcement by end of week.", "We will ship the fix by Thursday.",
        "I'll have the report ready by Monday.", "Will share the screenshot in a minute.", "I'll reply properly tomorrow.",
        "I'll send the recap after the call.", "Let me find the file and share it.", "I'll send the invoice by 11:30.",
        "Will circle back with numbers on Friday.", "I'll get the quote from the vendor this week.", "You'll get the draft tonight.",
        "I'll share the figures in a couple of days.", "I'll send it over by the end of the month.",
    ]

    /// Sentences that aren't: questions, plans, wishes, maybes, conditions,
    /// refusals, and what companies say as promises.
    static let notPromises = [
        "Can you send the deck?", "Could you share the numbers by Friday?", "Will you be at the offsite?", "Let me know if Friday works.",
        "We should grab coffee sometime!", "I'll be in Berlin next week.", "I'll be out of office until Monday.",
        "I'll try to send it tomorrow.", "Hopefully I can share it this week.", "Maybe I'll send the deck later.",
        "I'll probably have it by Friday.", "If you send the logo, I'll update the deck.", "Once you approve, I'll ship it.",
        "I won't be able to make it.", "I can't send it before Monday.", "Thanks, got it.", "Sounds good!",
        "You'll receive a verification code shortly.", "We'll email you when your order ships.", "Your order will be shipped tomorrow.",
        "We will notify you about changes to your account.", "I'll need the numbers by Friday.", "I'll have to check my calendar.",
        "I might send something next week.", "We'll see how it goes.", "I think I'll pass on this one.", "Not sure I'll get to it.",
        "Would you mind sending the recording?", "I'll miss the meeting tomorrow.", "Did you send the contract?",
        "Great to meet you yesterday.", "The deck is attached.", "Here are the numbers.", "I sent it on Friday.",
        "When you get a chance, send me the file.", "I'll send it if I can find it.", "Unless something comes up, I'll be there.",
        "I should be able to share it Friday.", "At some point I'll write it up.", "I'll take that as a yes.",
        // What a month of real mail held: cold sequences and offers.
        "Reply \"no thx\" and I'll disappear from your inbox.", "Reply with YES and I'll show you how it works.",
        "If so, I'll get you qualified sales calls.", "I'll keep this brief, I know you are busy.",
        "Say the word and I'll leave you be.", "If you're interested, I'll send over a time to chat.",
        "Write back and you'll get me, not a bot.", "I will stop reaching out.", "I can send a list of endpoints if useful.",
        "We will need to schedule a visit first.",
    ]

    @Test func strictOnTheWayIn() {
        let caught = Self.promises.filter { MailPromise.reading($0) != nil }
        let wrong = Self.notPromises.filter { MailPromise.reading($0) != nil }
        let recall = Double(caught.count) / Double(Self.promises.count)
        let precision = Double(caught.count) / Double(caught.count + wrong.count)
        #expect(wrong.isEmpty, "read as promises: \(wrong)")
        #expect(precision >= 0.97, "precision \(precision)")
        #expect(recall >= 0.9, "missed: \(Self.promises.filter { MailPromise.reading($0) == nil })")
    }

    /// Theirs: their own words, to you.
    @Test func theirsAreToYou() {
        #expect(MailPromise.theirReading("I'll get the contract signed and back to you by Monday.") != nil)
        #expect(MailPromise.theirReading("I'll send you the term sheet Monday.") != nil)
        #expect(MailPromise.theirReading("You'll have the logo files tomorrow.") != nil)
        #expect(MailPromise.theirReading("I'll be at the conference all week.") == nil)
        #expect(MailPromise.theirReading("We'll email you when your order ships.") == nil)
        #expect(MailPromise.theirReading("I'll think about it.") == nil)
    }

    // MARK: - the day

    func due(_ sentence: String, at: Date = wednesday) -> MailPromise.Due? { MailPromise.when(in: sentence, at: at) }

    @Test func theDayReadRight() throws {
        let calendar = Calendar.current
        let friday = try #require(due("I'll send it by Friday."))
        #expect(calendar.component(.weekday, from: friday.date) == 6 && calendar.component(.hour, from: friday.date) == 18)
        #expect(!friday.soft && !friday.timed)
        // "Wednesday" said on a Wednesday morning is today; in the evening, next week's.
        let today = try #require(due("I'll send it Wednesday.", at: Self.wednesday))
        #expect(calendar.isDate(today.date, inSameDayAs: Self.wednesday))
        let evening = Self.wednesday.addingTimeInterval(8 * 3600)
        let nextWeek = try #require(due("I'll send it Wednesday.", at: evening))
        #expect(nextWeek.date.timeIntervalSince(Self.wednesday) > 6 * 86_400)
        // A week is a span, late from its end.
        let week = try #require(due("I'll draft it this week."))
        #expect(week.soft && calendar.component(.weekday, from: week.date) == 6)
        let next = try #require(due("I'll send it next week."))
        #expect(next.soft && next.date.timeIntervalSince(Self.wednesday) > 7 * 86_400)
        // Tomorrow morning is a morning.
        let morning = try #require(due("I'll send the logo files tomorrow morning."))
        #expect(calendar.component(.hour, from: morning.date) == 10 && calendar.isDate(morning.date, inSameDayAs: Self.wednesday.addingTimeInterval(86_400)))
        // A time of day said: timed.
        let half = try #require(due("I'll send the invoice by 11:30."))
        #expect(half.timed && calendar.component(.hour, from: half.date) == 11 && calendar.component(.minute, from: half.date) == 30)
        let three = try #require(due("Will finish the mockups by 3pm tomorrow."))
        #expect(three.timed && calendar.component(.hour, from: three.date) == 15
                && calendar.isDate(three.date, inSameDayAs: Self.wednesday.addingTimeInterval(86_400)))
        let couple = try #require(due("I'll share it in a couple of days."))
        #expect(couple.soft && calendar.isDate(couple.date, inSameDayAs: Self.wednesday.addingTimeInterval(2 * 86_400)))
    }

    // MARK: - its title and words

    func promise(_ quote: String, person: String = "Olya Petrova", address: String = "olya@acme.io", theirs: Bool = false,
                 at: Date = wednesday.addingTimeInterval(-86_400), now: Date = wednesday) -> MailPromised {
        let read = theirs ? MailPromise.theirReading(quote) : MailPromise.reading(quote)
        let due = MailPromise.when(in: quote, at: at)
        return MailPromised(message: "m", thread: "t-" + quote.prefix(12), quote: quote, person: person, address: address,
                            kind: read?.kind ?? .word, due: due?.date, at: at, state: read?.judgment == true ? .judgment : .open,
                            theirs: theirs, soft: due?.soft ?? false, timed: due?.timed ?? false)
    }

    @Test func theRowSaysTheThingToDo() {
        #expect(Promises.title(promise("I'll send you the deck by Friday.")) == "Send Olya the deck")
        #expect(Promises.title(promise("Will intro you to Kenji tomorrow.")) == "Introduce Olya to Kenji")
        #expect(Promises.title(promise("Sure, I'll send the logo files tomorrow morning.", person: "Ana Ruiz")) == "Send the logo files")
        #expect(Promises.title(promise("You'll have the numbers by Friday.")) == "Send Olya the numbers")
        #expect(Promises.title(promise("I'll get the contract signed and back to you by Monday.", person: "Dana Lee", theirs: true))
                == "Dana owes you the contract signed")
        #expect(Promises.title(promise("I'll send you the term sheet Monday.", person: "Mark Chen", theirs: true)) == "Mark owes you the term sheet")
        #expect(Promises.title(promise("Let me think about it and get back to you.")) == "Think about it and get back to Olya")
    }

    @Test func itsWordsInCalendarDays() {
        let now = Self.wednesday
        let early = now.addingTimeInterval(-3600)
        #expect(Promises.status(promise("I'll send it today.", at: early), now: now) == "Due today")
        #expect(Promises.status(promise("I'll send it tonight.", at: early), now: now) == "Due tonight")
        #expect(Promises.status(promise("I'll send it tomorrow.", at: early), now: now) == "Due tomorrow")
        #expect(Promises.status(promise("I'll send it by 11:30.", at: now.addingTimeInterval(-3600)), now: now) == "In 1h 30m")
        #expect(Promises.status(promise("I'll send it Monday.", at: now.addingTimeInterval(-5 * 86_400)), now: now) == "2 days late")
        #expect(Promises.status(promise("I'll send the deck.", at: now.addingTimeInterval(-4 * 86_400)), now: now) == "4 days ago")
        #expect(Promises.status(promise("I'll send it tomorrow morning.", at: now.addingTimeInterval(-86_400)), now: now) == "Due this morning")
    }

    // MARK: - its window

    func item(_ promise: MailPromised, heard: Bool = false) -> Promises.Item { Promises.Item(promise: promise, account: "a", heard: heard) }

    @Test func aRowOnlyInItsWindow() {
        let now = Self.wednesday
        // Yours on its day, not the day before.
        let early = now.addingTimeInterval(-3600)
        #expect(Promises.due(item(promise("I'll send it today.", at: early)), now: now))
        #expect(!Promises.due(item(promise("I'll send it tomorrow.", at: early)), now: now))
        #expect(Promises.due(item(promise("I'll send it tomorrow.", at: early)), now: now.addingTimeInterval(86_400)))
        // With a time: its last two hours.
        let timed = promise("I'll send it by 5pm.", at: now.addingTimeInterval(-3600))
        #expect(!Promises.due(item(timed), now: now))
        #expect(Promises.due(item(timed), now: now.addingTimeInterval(6 * 3600)))
        // A week: from Thursday.
        let week = promise("I'll draft it this week.", at: now.addingTimeInterval(-2 * 86_400))
        #expect(!Promises.due(item(week), now: now))
        #expect(Promises.due(item(week), now: now.addingTimeInterval(86_400)))
        // No day: a thing from its third day, words never.
        #expect(!Promises.due(item(promise("I'll send the deck.", at: now.addingTimeInterval(-86_400))), now: now))
        #expect(Promises.due(item(promise("I'll send the deck.", at: now.addingTimeInterval(-3 * 86_400 - 60))), now: now))
        #expect(!Promises.due(item(promise("I'll reply properly.", at: now.addingTimeInterval(-5 * 86_400))), now: now))
        // A week after its day it is history; three weeks after it was said, too.
        #expect(!Promises.due(item(promise("I'll send it Monday.", at: now.addingTimeInterval(-12 * 86_400))), now: now))
        // Theirs: after its day, while they say nothing.
        let theirs = promise("I'll send you the term sheet Monday.", person: "Mark", theirs: true, at: now.addingTimeInterval(-5 * 86_400))
        #expect(Promises.due(item(theirs), now: now))
        #expect(!Promises.due(item(theirs, heard: true), now: now))
        let notYet = promise("I'll send you the term sheet Friday.", person: "Mark", theirs: true)
        #expect(!Promises.due(item(notYet), now: now))
        // Done, moved, not a promise: never.
        var done = promise("I'll send it today.", at: early)
        done.state = .done
        #expect(!Promises.due(item(done), now: now))
        done.state = .not
        #expect(!Promises.due(item(done), now: now))
    }

    // MARK: - the field and the budget

    static func hint(_ id: String, due: TimeInterval? = nil, day: Bool? = nil) -> Hint {
        var hint = Hint(id: id, icon: .symbol("x"), title: id, detail: "", due: due.map { wednesday.addingTimeInterval($0) }, source: .noticed)
        hint.day = day
        return hint
    }

    @Test func onePromiseInTheTwoRows() {
        let all: (String) -> Bool = { _ in true }
        let queue = [Self.hint("promise.mine.mail.a"), Self.hint("promise.mine.mail.b"), Self.hint("mail.c")]
        #expect(Hints.top(queue, room: 2, may: all).map(\.id) == ["promise.mine.mail.a", "mail.c"])
        // Only promises: they may fill the room.
        let only = [Self.hint("promise.mine.mail.a"), Self.hint("promise.mine.mail.b")]
        #expect(Hints.top(only, room: 2, may: all).map(\.id) == ["promise.mine.mail.a", "promise.mine.mail.b"])
        // One the budget holds back: the next row takes its place.
        #expect(Hints.top(queue, room: 2, may: { $0 != "promise.mine.mail.a" }).map(\.id) == ["promise.mine.mail.b", "mail.c"])
        #expect(Hints.top(queue, room: 2, may: { _ in false }).map(\.id) == ["mail.c"])
    }

    @Test func aMeetingSoonGoesFirstAndADayNeverCountsDown() {
        let meeting = Self.hint("noticed.meeting.x", due: 20 * 60)
        var today = Self.hint("promise.mine.mail.a", due: 30 * 60, day: true)
        today.day = true
        let late = Self.hint("promise.mine.mail.b", due: -2 * 86_400, day: true)
        let mail = Self.hint("mail.c")
        let order = Hints.order(found: [], noticed: [mail, late, today, meeting], setup: [], now: Self.wednesday).map(\.id)
        #expect(order == ["noticed.meeting.x", "promise.mine.mail.b", "promise.mine.mail.a", "mail.c"])
        // A time said counts down; a day doesn't.
        let timed = Self.hint("promise.mine.mail.t", due: 40 * 60)
        #expect(Hints.order(found: [], noticed: [mail, timed], setup: [], now: Self.wednesday).first?.id == "promise.mine.mail.t")
    }

    @Test func theirsLateAfterMail() {
        let theirs = Self.hint("promise.theirs.mail.x", due: -3 * 86_400, day: true)
        let mail = Self.hint("mail.c")
        #expect(Hints.order(found: [], noticed: [theirs, mail], setup: [], now: Self.wednesday).map(\.id) == ["mail.c", "promise.theirs.mail.x"])
    }

    @Test func oneRowAThread() {
        var mail = Self.hint("mail.t1")
        mail.url = URL(string: "yab://mail#thread=a%7Ct1")
        var bill = Self.hint("mail.t2")
        bill.url = URL(string: "yab://mail#thread=a%7Ct2")
        bill.kind = Noticing.Kind.mailDue.rawValue
        var mine = Self.hint("promise.mine.mail.t1")
        mine.url = URL(string: "yab://mail#thread=a%7Ct1")
        mine.kind = Noticing.Kind.promiseMine.rawValue
        var theirs = Self.hint("promise.theirs.mail.t1")
        theirs.url = URL(string: "yab://mail#thread=a%7Ct1")
        theirs.kind = Noticing.Kind.promiseTheirs.rawValue
        var onBill = Self.hint("promise.mine.mail.t2")
        onBill.url = URL(string: "yab://mail#thread=a%7Ct2")
        onBill.kind = Noticing.Kind.promiseMine.rawValue
        let out = Noticing.oneRowAThread([mail, bill], promises: [theirs, mine, onBill]).map(\.id)
        #expect(out == ["mail.t2", "promise.mine.mail.t1"])
    }

    @Test func ignoredThreeDaysLeavesTheRowsAndANudgeWaits() {
        let now = Self.wednesday
        var seen = Promises.Seen()
        seen.days = ["2026-10-12", "2026-10-13"]
        #expect(!seen.ignored(now: now))
        seen.days.append("2026-10-14")
        #expect(seen.ignored(now: now))
        // Dealt with on the 13th: only the 14th counts after it.
        seen.acted = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 12))!.timeIntervalSince1970
        #expect(!seen.ignored(now: now))
        var nudged = Promises.Seen()
        nudged.nudged = now.addingTimeInterval(-2 * 86_400).timeIntervalSince1970
        #expect(nudged.away(now: now))
        #expect(!nudged.away(now: now.addingTimeInterval(2 * 86_400)))
        var later = Promises.Seen()
        later.until = now.addingTimeInterval(3600).timeIntervalSince1970
        #expect(later.away(now: now) && !later.away(now: now.addingTimeInterval(7200)))
    }

    @Test func saidOnASite() {
        #expect(Promises.site("app.slack.com") == "Slack" && Promises.site("linear.app") == "Linear")
        #expect(Promises.site("github.com") == "GitHub" && Promises.site("forum.example.com") == "Example")
        let site = MailPromised(message: "s", thread: "app.slack.com/client/T1/C2", quote: "Sure, I'll send the logo files tomorrow morning.",
                                person: "", address: "app.slack.com", kind: .file, at: Self.wednesday)
        #expect(Promises.title(site) == "Send the logo files")
        let gives = MailPromised(message: "g", thread: "x", quote: "You'll have the numbers by Friday.", person: "", address: "linear.app",
                                 kind: .file, at: Self.wednesday)
        #expect(Promises.title(gives) == "Send the numbers")
        let with = MailPromised(message: "w", thread: "x", quote: "I'll share the deck with you tonight.", person: "", address: "app.slack.com",
                                kind: .file, at: Self.wednesday)
        #expect(Promises.title(with) == "Share the deck")
        #expect(MailPromise.reading("Reply YES and I'll send you a free audit.") == nil)
    }

    /// Said on a site to a channel: no one's name for "your" either.
    @Test func yourOnASiteNamesNoOne() {
        let review = MailPromised(message: "r", thread: "x", quote: "I'll review your PR tomorrow.", person: "", address: "github.com",
                                  kind: .word, at: Self.wednesday)
        #expect(Promises.title(review) == "Review the PR")
        let invoice = MailPromised(message: "i", thread: "x", quote: "I'll send your invoice by Friday.", person: "", address: "app.slack.com",
                                   kind: .file, at: Self.wednesday)
        #expect(Promises.title(invoice) == "Send the invoice")
        // To someone by name, still theirs.
        #expect(Promises.title(promise("I'll review your PR tomorrow.")) == "Review Olya's PR")
    }

    @Test func aSentencesShape() {
        #expect(Promises.fingerprint("I'll be back online tomorrow at 9!") == Promises.fingerprint("I'll be back online tomorrow at 10."))
        #expect(Promises.fingerprint("I'll send the deck") != Promises.fingerprint("I'll send the numbers"))
    }

    // MARK: - a store, both ways

    static let me = MailPerson(name: "Me", address: "me@acme.io")
    static let dana = MailPerson(name: "Dana Lee", address: "dana@north.vc")
    static let shop = MailPerson(name: "Acme Store", address: "orders@shop.example")

    @Test func theirsAreReadAndKeptByTheirFile() throws {
        let now = Date()
        let store = MailStore(file: MailStore.memory)
        store.set("me", Self.me.address)
        store.put([
            MailMessage(id: "a", thread: "c", from: Self.me, to: [Self.dana], subject: "Contract", snippet: "", date: now.addingTimeInterval(-60 * 3600),
                        labels: ["SENT"], text: "Could you get the contract signed?"),
            MailMessage(id: "b", thread: "c", from: Self.dana, to: [Self.me], subject: "Re: Contract", snippet: "",
                        date: now.addingTimeInterval(-50 * 3600), labels: ["INBOX"],
                        text: "Sure, I'll get the contract signed and back to you by Monday."),
            MailMessage(id: "s", thread: "o", from: Self.shop, to: [Self.me], subject: "Your order", snippet: "",
                        date: now.addingTimeInterval(-10 * 3600), labels: ["INBOX"], listUnsubscribe: true,
                        text: "We'll send you a tracking link tomorrow."),
        ])
        MailPromise.run(store, now: now)
        let theirs = MailPromise.open(in: store, now: now, theirs: true)
        #expect(theirs.count == 1)
        let one = try #require(theirs.first)
        #expect(one.address == "dana@north.vc" && one.theirs && one.kind == .file)
        // Nothing of yours: a question promises nothing.
        #expect(MailPromise.open(in: store, now: now).isEmpty)
        let file = MailFile(part: "1", name: "Contract signed.pdf", mime: "application/pdf", size: 90_000, attachmentID: "x", contentID: "", inline: false)
        store.put([MailMessage(id: "d", thread: "c", from: Self.dana, to: [Self.me], subject: "Re: Contract", snippet: "",
                               date: now.addingTimeInterval(-1 * 3600), labels: ["INBOX"], text: "Here it is.", files: [file])])
        MailPromise.run(store, now: now)
        #expect(MailPromise.open(in: store, now: now, theirs: true).isEmpty)
    }

    /// A cold mail's promise to you is no promise: theirs only in a thread
    /// you wrote in before.
    @Test func theirsOnlyInYourConversations() {
        let now = Date()
        let store = MailStore(file: MailStore.memory)
        store.set("me", Self.me.address)
        store.put([MailMessage(id: "x", thread: "cold", from: Self.dana, to: [Self.me], subject: "Quick question", snippet: "",
                               date: now.addingTimeInterval(-5 * 3600), labels: ["INBOX"],
                               text: "I'll send you the case study tomorrow.")])
        MailPromise.run(store, now: now)
        #expect(MailPromise.open(in: store, now: now, theirs: true).isEmpty)
    }

    @Test func yoursGoToWhomYouNamed() {
        let mark = MailPerson(name: "Mark Chen", address: "mark@north.vc")
        let message = MailMessage(id: "m", thread: "t", from: Self.me, to: [Self.dana, mark], subject: "Deck", snippet: "",
                                  date: Self.wednesday, labels: ["SENT"], text: "Mark, I'll send you the deck by Friday.")
        #expect(MailPromise.promises(in: message).first?.address == "mark@north.vc")
    }
}
