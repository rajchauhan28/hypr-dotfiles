function readFile(path) {
    try {
        var file = Qt.openFileUrl("file://" + path)
        var text = file.readAll()
        file.close()
        return text
    } catch (e) {
        console.log("File read error:", e)
        return ""
    }
}
