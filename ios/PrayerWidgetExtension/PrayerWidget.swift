import SwiftUI
import WidgetKit

private let appGroupId = "group.com.abdalmqadma.munib"
private let widgetKind = "PrayerWidget"

private struct PrayerPoint: Codable, Hashable {
    let name: String
    let at: Int64

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(at) / 1000.0)
    }
}

private struct PrayerWidgetEntry: TimelineEntry {
    let date: Date
    let nextPrayer: PrayerPoint?
    let upcomingPrayers: [PrayerPoint]
    let languageCode: String
    let locationName: String
    let use24HourFormat: Bool

    var isArabic: Bool {
        languageCode.lowercased().hasPrefix("ar")
    }
}

private struct PrayerWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerWidgetEntry {
        let now = Date()
        return PrayerWidgetEntry(
            date: now,
            nextPrayer: PrayerPoint(
                name: "Maghrib",
                at: Int64(now.addingTimeInterval(38 * 60).timeIntervalSince1970 * 1000)
            ),
            upcomingPrayers: [],
            languageCode: "ar",
            locationName: "غزة",
            use24HourFormat: true
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (PrayerWidgetEntry) -> Void
    ) {
        completion(makeEntry(at: Date()))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<PrayerWidgetEntry>) -> Void
    ) {
        let now = Date()
        let schedule = readSchedule()

        var refreshDates = [now]
        refreshDates.append(
            contentsOf: schedule
                .filter { $0.date > now }
                .prefix(20)
                .map { $0.date.addingTimeInterval(1) }
        )

        let uniqueRefreshDates = Array(Set(refreshDates.map { Int($0.timeIntervalSince1970) }))
            .sorted()
            .map { Date(timeIntervalSince1970: TimeInterval($0)) }

        let entries = uniqueRefreshDates.map { date in
            makeEntry(at: date, schedule: schedule)
        }

        if entries.count > 1 {
            completion(Timeline(entries: entries, policy: .atEnd))
        } else {
            completion(
                Timeline(
                    entries: entries,
                    policy: .after(now.addingTimeInterval(15 * 60))
                )
            )
        }
    }

    private func makeEntry(
        at date: Date,
        schedule suppliedSchedule: [PrayerPoint]? = nil
    ) -> PrayerWidgetEntry {
        let defaults = sharedDefaults
        let schedule = suppliedSchedule ?? readSchedule()
        let future = schedule.filter { $0.date > date }
        let nextPrayer = future.first ?? readCachedNextPrayer(after: date, defaults: defaults)

        return PrayerWidgetEntry(
            date: date,
            nextPrayer: nextPrayer,
            upcomingPrayers: Array(future.prefix(5)),
            languageCode: defaults.string(forKey: "widget_language") ?? "ar",
            locationName: defaults.string(forKey: "widget_location")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            use24HourFormat: defaults.object(forKey: "widget_use_24h") as? Bool ?? true
        )
    }

    private func readSchedule() -> [PrayerPoint] {
        guard
            let raw = sharedDefaults.string(forKey: "prayer_schedule_json"),
            let data = raw.data(using: .utf8),
            let points = try? JSONDecoder().decode([PrayerPoint].self, from: data)
        else {
            return []
        }

        return points
            .filter { !$0.name.isEmpty && $0.at > 0 }
            .sorted { $0.at < $1.at }
    }

    private func readCachedNextPrayer(
        after date: Date,
        defaults: UserDefaults
    ) -> PrayerPoint? {
        guard
            let name = defaults.string(forKey: "next_prayer"),
            !name.isEmpty
        else {
            return nil
        }

        let rawEpoch = defaults.object(forKey: "next_prayer_at") as? NSNumber
            ?? defaults.object(forKey: "next_prayer_epoch_ms") as? NSNumber
        let epoch = rawEpoch?.int64Value ?? 0
        let point = PrayerPoint(name: name, at: epoch)
        return point.date > date ? point : nil
    }

    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupId) ?? .standard
    }
}

private struct PrayerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerWidgetEntry

    private let gold = Color(red: 244 / 255, green: 199 / 255, blue: 106 / 255)
    private let mutedWhite = Color.white.opacity(0.76)

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemLarge:
                largeView
            default:
                mediumView
            }
        }
        .padding(family == .systemSmall ? 12 : 14)
        .munibWidgetBackground()
        .environment(\.layoutDirection, entry.isArabic ? .rightToLeft : .leftToRight)
        .widgetURL(URL(string: "munib://home"))
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                prayerIcon
                Text(entry.isArabic ? "الصلاة التالية" : "Next prayer")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(mutedWhite)
                    .lineLimit(1)
            }

            if let next = entry.nextPrayer {
                Text(localizedPrayerName(next.name))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                countdown(to: next.date)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .environment(\.layoutDirection, .leftToRight)

                Text(entry.isArabic ? "متبقي" : "remaining")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(gold)
            } else {
                emptyState
            }

            Spacer(minLength: 0)

            if !entry.locationName.isEmpty {
                Label(entry.locationName, systemImage: "location.fill")
                    .font(.caption2)
                    .foregroundStyle(mutedWhite)
                    .lineLimit(1)
            }
        }
    }

    private var mediumView: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    prayerIcon
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.isArabic ? "الصلاة التالية" : "Next prayer")
                            .font(.caption2)
                            .foregroundStyle(mutedWhite)

                        if let next = entry.nextPrayer {
                            Text(localizedPrayerName(next.name))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(gold)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 0)

                Text(dhikr(for: entry.date))
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.9))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 5) {
                if let next = entry.nextPrayer {
                    countdown(to: next.date)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .environment(\.layoutDirection, .leftToRight)

                    Text(entry.isArabic ? "متبقي" : "remaining")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(gold)
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(formattedDate(entry.date))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if !entry.locationName.isEmpty {
                    Label(entry.locationName, systemImage: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(mutedWhite)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                prayerIcon

                VStack(alignment: .leading, spacing: 3) {
                    Text(formattedDate(entry.date))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)

                    if !entry.locationName.isEmpty {
                        Label(entry.locationName, systemImage: "location.fill")
                            .font(.caption)
                            .foregroundStyle(mutedWhite)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Text("منيب")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(gold)
            }

            if let next = entry.nextPrayer {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.isArabic ? "الصلاة التالية" : "Next prayer")
                        .font(.caption)
                        .foregroundStyle(mutedWhite)

                    HStack(alignment: .firstTextBaseline) {
                        Text(localizedPrayerName(next.name))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(gold)

                        Spacer()

                        countdown(to: next.date)
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                emptyState
                    .padding(.vertical, 16)
            }

            Text(entry.isArabic ? "المواقيت القادمة" : "Upcoming prayers")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                if entry.upcomingPrayers.isEmpty {
                    Text(entry.isArabic ? "افتح منيب لتحميل المواقيت" : "Open Munib to load prayer times")
                        .font(.caption)
                        .foregroundStyle(mutedWhite)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                } else {
                    ForEach(Array(entry.upcomingPrayers.prefix(5).enumerated()), id: \.offset) { index, prayer in
                        prayerRow(prayer)

                        if index < min(entry.upcomingPrayers.count, 5) - 1 {
                            Divider().overlay(Color.white.opacity(0.12))
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Spacer(minLength: 0)

            Text(dhikr(for: entry.date))
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.88))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
    }

    private var prayerIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(gold)
            .frame(width: 34, height: 34)
            .background(Color(red: 11 / 255, green: 31 / 255, blue: 58 / 255), in: Circle())
            .overlay(Circle().stroke(gold.opacity(0.65), lineWidth: 1))
    }

    private var iconName: String {
        let name = entry.nextPrayer?.name.lowercased() ?? ""
        return ["fajr", "maghrib", "isha"].contains(name) ? "moon.stars.fill" : "sun.max.fill"
    }

    @ViewBuilder
    private func countdown(to date: Date) -> some View {
        if date > entry.date {
            Text(timerInterval: entry.date...date, countsDown: true)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        } else {
            Text("00:00")
        }
    }

    private func prayerRow(_ prayer: PrayerPoint) -> some View {
        HStack(spacing: 10) {
            Text(localizedPrayerName(prayer.name))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Text(formattedPrayerTime(prayer.date))
                .font(.caption.monospacedDigit())
                .foregroundStyle(gold)
                .environment(\.layoutDirection, .leftToRight)
        }
        .padding(.vertical, 9)
    }

    private var emptyState: some View {
        Text(entry.isArabic ? "افتح التطبيق مرة واحدة لتحميل المواقيت" : "Open Munib once to load prayer times")
            .font(.caption)
            .foregroundStyle(mutedWhite)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func localizedPrayerName(_ name: String) -> String {
        guard entry.isArabic else { return name }

        switch name.lowercased() {
        case "fajr": return "الفجر"
        case "sunrise": return "الشروق"
        case "dhuhr": return "الظهر"
        case "asr": return "العصر"
        case "maghrib": return "المغرب"
        case "isha": return "العشاء"
        default: return name
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: entry.isArabic ? "ar" : "en")
        formatter.dateFormat = entry.isArabic ? "EEEE d MMMM" : "EEE, d MMMM"
        return formatter.string(from: date)
    }

    private func formattedPrayerTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: entry.isArabic ? "ar" : "en_US_POSIX")
        formatter.dateFormat = entry.use24HourFormat ? "HH:mm" : "h:mm a"
        return formatter.string(from: date)
    }

    private func dhikr(for date: Date) -> String {
        let arabic = [
            "سبحان الله وبحمده",
            "أستغفر الله وأتوب إليه",
            "لا حول ولا قوة إلا بالله",
            "اللهم صل وسلم على نبينا محمد",
            "سبحان الله العظيم",
            "الحمد لله رب العالمين",
            "لا إله إلا الله وحده لا شريك له",
            "حسبي الله ونعم الوكيل",
        ]
        let english = [
            "Glory be to Allah and praise be to Him",
            "I seek Allah's forgiveness and repent to Him",
            "There is no power nor strength except through Allah",
            "O Allah, send peace and blessings upon Muhammad",
            "Glory be to Allah, the Magnificent",
            "All praise is due to Allah",
            "There is no god but Allah alone",
            "Allah is sufficient for me and the best Disposer of affairs",
        ]

        let list = entry.isArabic ? arabic : english
        let minute = Int(date.timeIntervalSince1970 / 60)
        return list[abs(minute) % list.count]
    }
}

private struct PrayerWidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 9 / 255, green: 25 / 255, blue: 47 / 255),
                Color(red: 15 / 255, green: 44 / 255, blue: 76 / 255),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private extension View {
    @ViewBuilder
    func munibWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                PrayerWidgetBackground()
            }
        } else {
            background(PrayerWidgetBackground())
        }
    }
}

@main
struct PrayerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: widgetKind, provider: PrayerWidgetProvider()) { entry in
            PrayerWidgetView(entry: entry)
        }
        .configurationDisplayName("Munib Prayer")
        .description("Prayer times, the next prayer and a live countdown from Munib.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
