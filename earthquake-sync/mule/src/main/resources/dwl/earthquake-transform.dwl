%dw 2.0
output application/json
var jst = |+09:00| as TimeZone
fun toDt(s) = if (isEmpty(s)) null
    else (s[0 to 18] as LocalDateTime {format: "yyyy/MM/dd HH:mm:ss"}) ++ jst
fun nullIfNeg(n) = if (n == null or n < 0) null else n
fun scaleLabel(c) = c match {
    case 10 -> "1"
    case 20 -> "2"
    case 30 -> "3"
    case 40 -> "4"
    case 45 -> "5-"
    case 46 -> "5-以上(未入手)"
    case 50 -> "5+"
    case 55 -> "6-"
    case 60 -> "6+"
    case 70 -> "7"
    else -> null
}
---
payload map (e) -> {
    id: e.id,
    occurredAt: toDt(e.earthquake.time),
    issuedAt: toDt(e.issue.time),
    hypocenterName: e.earthquake.hypocenter.name,
    latitude: nullIfNeg(e.earthquake.hypocenter.latitude),
    longitude: nullIfNeg(e.earthquake.hypocenter.longitude),
    depthKm: nullIfNeg(e.earthquake.hypocenter.depth),
    magnitude: nullIfNeg(e.earthquake.hypocenter.magnitude),
    maxScale: nullIfNeg(e.earthquake.maxScale),
    maxScaleLabel: scaleLabel(e.earthquake.maxScale),
    domesticTsunami: e.earthquake.domesticTsunami,
    foreignTsunami: e.earthquake.foreignTsunami,
    issueType: e.issue."type",
    issueSource: e.issue.source,
    correct: e.issue.correct,
    comment: e.comments.freeFormComment,
    points: (e.points default []) map (p) -> {
        pref: p.pref, addr: p.addr, isArea: p.isArea, scale: p.scale
    }
}
