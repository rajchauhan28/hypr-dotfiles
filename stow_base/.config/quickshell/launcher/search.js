// Ranking shared by every launcher mode.
//
// .pragma library keeps one copy of this across the panel's delegates instead
// of re-evaluating it per QML scope, which matters because score() runs over
// the whole candidate list on every keystroke.
.pragma library

// Subsequence fuzzy match. Returns -1 when `needle` is not a subsequence of
// `haystack` at all, otherwise a score where higher is better.
//
// The bonuses are what stop "fox" ranking Firefox below some random file with
// an f, an o and an x scattered through it: consecutive runs and word starts
// are worth far more than a bare character hit.
function fuzzy(haystack, needle) {
    if (!needle)
        return 0;
    if (!haystack)
        return -1;

    var h = haystack.toLowerCase();
    var n = needle.toLowerCase();

    // Exact and prefix hits skip the walk entirely — they should always beat
    // anything the character scan can produce.
    if (h === n)
        return 10000;
    if (h.indexOf(n) === 0)
        return 5000 - h.length;

    var contiguous = h.indexOf(n);
    if (contiguous > 0)
        return 3000 - contiguous * 2 - h.length;

    var score = 0;
    var hi = 0;
    var run = 0;

    for (var ni = 0; ni < n.length; ni++) {
        var c = n[ni];
        var found = -1;
        while (hi < h.length) {
            if (h[hi] === c) {
                found = hi;
                break;
            }
            hi++;
        }
        if (found === -1)
            return -1;

        // Start of a word (or of the string) is a strong signal — it is how
        // "vsc" finds "Visual Studio Code".
        var prev = found > 0 ? h[found - 1] : " ";
        if (found === 0 || prev === " " || prev === "-" || prev === "_" || prev === "." || prev === "/")
            score += 40;
        else
            score += 4;

        run = (found === hi && ni > 0) ? run + 1 : 0;
        score += run * 12;

        hi = found + 1;
    }

    // Shorter haystacks win ties, so "Files" beats "Files (Nautilus) Extras".
    return score - Math.floor(h.length / 4);
}

// Best score across several fields, each with its own weight.
//
// Only the primary field (weight 1) gets the full subsequence walk. Secondary
// fields -- comment, keywords, generic name, a file's parent path -- match on
// substring alone, because scattered-character matching over a sentence hits
// almost everything: "firef" found Thunar, Dolphin and OBS through their
// descriptions before this split. The visible name is the only field where a
// user is deliberately spelling out an abbreviation.
function scoreFields(fields, needle) {
    var best = -1;
    for (var i = 0; i < fields.length; i++) {
        var f = fields[i];
        if (!f || !f.text)
            continue;

        var w = (f.weight === undefined) ? 1 : f.weight;
        var s;

        if (w >= 1) {
            s = fuzzy(f.text, needle);
        } else {
            var idx = f.text.toLowerCase().indexOf(needle.toLowerCase());
            s = (idx < 0) ? -1 : 2000 - idx * 2 - Math.floor(f.text.length / 4);
        }

        if (s < 0)
            continue;
        s = Math.floor(s * w);
        if (s > best)
            best = s;
    }
    return best;
}

// Frecency: a launch count decayed by age, in the spirit of Firefox's.
//
// Recency alone makes the list thrash after one stray launch; raw counts
// freeze the order weeks in. Halving the weight every 14 days lets a habit
// build and also lets an abandoned app fall away on its own.
function frecency(stat, nowMs) {
    if (!stat || !stat.count)
        return 0;
    var ageDays = (nowMs - (stat.last || 0)) / 86400000;
    if (ageDays < 0)
        ageDays = 0;
    var decay = Math.pow(0.5, ageDays / 14);
    return stat.count * decay;
}

// Final ordering. With no query this is pure frecency (so an empty launcher
// opens on what you actually use); with a query the match dominates and
// frecency only breaks ties between comparable matches.
function rank(entries, needle, stats, nowMs) {
    var out = [];
    for (var i = 0; i < entries.length; i++) {
        var e = entries[i];
        var fr = frecency(stats[e.id], nowMs);

        if (!needle) {
            out.push({ entry: e, score: fr * 1000 + (e.bias || 0) });
            continue;
        }

        var m = scoreFields(e.fields, needle);
        if (m < 0)
            continue;
        out.push({ entry: e, score: m + Math.min(fr, 20) * 25 + (e.bias || 0) });
    }

    out.sort(function (a, b) {
        if (b.score !== a.score)
            return b.score - a.score;
        // Stable, predictable fallback so equal scores do not reshuffle
        // between keystrokes.
        return a.entry.label.localeCompare(b.entry.label);
    });
    return out;
}
