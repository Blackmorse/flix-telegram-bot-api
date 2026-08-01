mod TelegramApi.Models.Tests {
    use TelegramApi.Models.OutgoingMessage
    use Util.Json.ToJson
    use Assert.{assertEq}

    @Test
    def testOutgoingTestMessageToJson(): Unit \ Assert =
        let message = OutgoingMessage.TextMessage({chatId = 12345i64, text = "Hello, world!"});
        let json = ToJson.toJson(message);
        let expectedJson = "{\"chat_id\":12345,\"text\":\"Hello, world!\"}";
        assertEq(expected = ToString.toString(json), expectedJson)
}
