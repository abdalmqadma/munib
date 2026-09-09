from pathlib import Path

path = Path('ios/PrayerWidgetExtension/PrayerWidget.swift')
text = path.read_text()

if '.accessoryRectangular' in text:
    print('iOS lock screen widget already patched')
    raise SystemExit(0)

old_body = '''    var body: some View {
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
        .environment(\\.layoutDirection, entry.isArabic ? .rightToLeft : .leftToRight)
        .widgetURL(URL(string: "munib://home"))
    }

'''

new_body = '''    var body: some View {
        Group {
            if family == .accessoryRectangular {
                lockScreenView
            } else {
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
            }
        }
        .environment(\\.layoutDirection, entry.isArabic ? .rightToLeft : .leftToRight)
        .widgetURL(URL(string: "munib://home"))
    }

    private var lockScreenView: some View {
        VStack(
            alignment: entry.isArabic ? .trailing : .leading,
            spacing: 3
        ) {
            if let next = entry.nextPrayer {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(localizedPrayerName(next.name))
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 4)

                    countdown(to: next.date)
                        .font(.headline.weight(.semibold).monospacedDigit())
                        .environment(\\.layoutDirection, .leftToRight)
                }
                .foregroundStyle(.primary)

                Text(shortDhikr(for: entry.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: entry.isArabic ? .trailing : .leading)
            } else {
                Text(entry.isArabic ? "افتح منيب لتحميل المواقيت" : "Open Munib to load prayer times")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
        }
    }

'''

if old_body not in text:
    raise SystemExit('body anchor not found')
text = text.replace(old_body, new_body, 1)

anchor = '''    private func dhikr(for date: Date) -> String {
'''
short_dhikr = '''    private func shortDhikr(for date: Date) -> String {
        let arabic = [
            "سبحان الله",
            "الحمد لله",
            "الله أكبر",
            "أستغفر الله",
            "حسبي الله",
        ]
        let english = [
            "Glory to Allah",
            "Praise be to Allah",
            "Allah is Greatest",
            "I seek forgiveness",
            "Allah is sufficient",
        ]

        let list = entry.isArabic ? arabic : english
        let minute = Int(date.timeIntervalSince1970 / 60)
        return list[abs(minute) % list.count]
    }

'''
if anchor not in text:
    raise SystemExit('dhikr anchor not found')
text = text.replace(anchor, short_dhikr + anchor, 1)

old_families = '''        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
'''
new_families = '''        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
'''
if old_families not in text:
    raise SystemExit('supportedFamilies anchor not found')
text = text.replace(old_families, new_families, 1)

path.write_text(text)
print('Patched iOS accessoryRectangular lock screen widget')
