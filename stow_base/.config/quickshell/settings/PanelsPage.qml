import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    spacing: Theme.gap

    Card {
        title: "TOP PANEL — SIZE"
        subtitle: "The dashboard that drops from the top edge"
        section: "topbar"
        keys: ["panelWidth", "panelHeight", "radiusPanel", "cornerFillet", "edgeLine"]

        SliderRow { section: "topbar"; key: "panelWidth"; label: "Width"; from: 700; to: 1800; step: 10; suffix: " px" }
        SliderRow { section: "topbar"; key: "panelHeight"; label: "Height"; from: 400; to: 1000; step: 10; suffix: " px" }
        SliderRow { section: "topbar"; key: "radiusPanel"; label: "Corner radius"; from: 0; to: 40; suffix: " px" }
        SliderRow { section: "topbar"; key: "cornerFillet"; label: "Rail fillet"; from: 0; to: 60; suffix: " px" }
        SliderRow { section: "topbar"; key: "edgeLine"; label: "Edge rail"; from: 0; to: 12; suffix: " px" }
    }

    Card {
        title: "TOP PANEL — SPACING & REVEAL"
        section: "topbar"
        keys: ["gap", "cardPadding", "hotspotHeight", "hotspotWidthFraction"]

        SliderRow { section: "topbar"; key: "gap"; label: "Gap between cards"; from: 4; to: 32; suffix: " px" }
        SliderRow { section: "topbar"; key: "cardPadding"; label: "Padding inside cards"; from: 6; to: 36; suffix: " px" }
        SliderRow { section: "topbar"; key: "hotspotHeight"; label: "Trigger height"; from: 2; to: 40; suffix: " px" }
        SliderRow {
            section: "topbar"; key: "hotspotWidthFraction"; label: "Trigger width"
            from: 0.05; to: 1.0; step: 0.05; decimals: 2; suffix: " of screen"
        }
    }

    Card {
        title: "SIDE PANEL — SIZE"
        subtitle: "The quick-settings strip on the right edge"
        section: "sidepanel"
        keys: ["iconSlot", "stripPadding", "panelWidth", "osdWidth", "radiusPanel", "cornerFillet", "edgeLine"]

        SliderRow { section: "sidepanel"; key: "iconSlot"; label: "Slot height"; from: 32; to: 80; suffix: " px" }
        SliderRow { section: "sidepanel"; key: "panelWidth"; label: "Strip width"; from: 36; to: 96; suffix: " px" }
        SliderRow { section: "sidepanel"; key: "stripPadding"; label: "Padding"; from: 2; to: 20; suffix: " px" }
        SliderRow { section: "sidepanel"; key: "osdWidth"; label: "Read-out width"; from: 80; to: 240; step: 2; suffix: " px" }
        SliderRow { section: "sidepanel"; key: "radiusPanel"; label: "Corner radius"; from: 0; to: 32; suffix: " px" }
        SliderRow { section: "sidepanel"; key: "cornerFillet"; label: "Rail fillet"; from: 0; to: 40; suffix: " px" }
        SliderRow { section: "sidepanel"; key: "edgeLine"; label: "Edge rail"; from: 0; to: 12; suffix: " px" }
    }

    Card {
        title: "SIDE PANEL — REVEAL"
        section: "sidepanel"
        keys: ["hotspotWidth", "hotspotHeightFraction"]

        SliderRow { section: "sidepanel"; key: "hotspotWidth"; label: "Trigger width"; from: 2; to: 40; suffix: " px" }
        SliderRow {
            section: "sidepanel"; key: "hotspotHeightFraction"; label: "Trigger height"
            from: 0.05; to: 1.0; step: 0.05; decimals: 2; suffix: " of screen"
        }
    }

    Card {
        title: "LEFT SIDEBAR — GEOMETRY"
        subtitle: "The always-visible vertical sidebar on the left screen edge"
        section: "leftbar"
        keys: ["barWidth", "iconSlot", "barPadding", "radiusPanel", "radiusSmall"]

        SliderRow { section: "leftbar"; key: "barWidth"; label: "Sidebar width"; from: 40; to: 90; suffix: " px" }
        SliderRow { section: "leftbar"; key: "iconSlot"; label: "Button size"; from: 28; to: 60; suffix: " px" }
        SliderRow { section: "leftbar"; key: "barPadding"; label: "Bar padding"; from: 4; to: 24; suffix: " px" }
        SliderRow { section: "leftbar"; key: "radiusPanel"; label: "Corner radius"; from: 0; to: 32; suffix: " px" }
        SliderRow { section: "leftbar"; key: "radiusSmall"; label: "Button corner radius"; from: 0; to: 20; suffix: " px" }
    }
}
