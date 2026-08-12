import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    spacing: Theme.gap

    Card {
        title: "LEFT SIDEBAR — GEOMETRY & SIZE"
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
