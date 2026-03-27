function truncateTitle(text) {
    if (!text) return 'New Chat'
    const cleaned = text.replace(/\n/g, ' ').trim()
    if (cleaned.length <= 28) return cleaned
    return cleaned.substring(0, 25) + '...'
}

function formatMessages(rows) {
    return rows.map(row => ({
        name: row.id,
        fields: {
            text: { stringValue: row.text },
            isKyle: { booleanValue: row.isKyle === 1 },
            timestamp: { doubleValue: row.timestamp },
            room: { stringValue: row.room },
            chatId: { stringValue: row.chatId || '' },
            imageBase64: row.imageBase64 ? { stringValue: row.imageBase64 } : undefined
        }
    }))
}

module.exports = {
    truncateTitle,
    formatMessages
}
