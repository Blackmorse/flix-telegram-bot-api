mod TelegramApi.Receiver.Tests {
    use Assert.{assertErr, fail, assertEq, assertTrue}
    use IoError.ErrorKind.ConnectionFailed
    use Net.{Https, HttpRequest}
    use Util.Json.JsonError
    use TelegramApi.Models.{TelegramBotToken, TelegramUpdate}
    use TelegramApi.Receiver.{Error, getUpdates}

    def botTokenHandler(token: String, f: Unit -> a \ ef): a \ (ef - TelegramBotToken) =
        run {
            f()
        } with handler TelegramBotToken {
            def getToken(resume) = resume(token)
        }

    def httpHandlerWithBody(body: String, f: Unit -> a \ ef): a \ (ef - Https) =
        run {
            f()
        } with handler Https {
            def request(_, resume) = resume(Ok(httpResponse(body)))
        }

    def textUpdateJsonString(updateId: Int64, text: String, chatId: Int64): String = 
        "{\"update_id\": ${updateId}, \"message\": {\"text\": \"${text}\", \"chat\": {\"id\": ${chatId}}}}"

    def httpResponse(body: String): Net.HttpResponse = 
        Net.HttpResponse({
            body = Net.Body.Text(body),
            headers = Map#{},
            status = 200,
            url = ""
        })

    @Test
    def testGetUpdatesReturnsNetworkErrorIfCaseOfRequestFailure(): Unit \ Assert = 
        run {
            let result = getUpdates(None);
            match result {
                case Err(Error.NetworkError(IoError(ConnectionFailed, _))) => ()
                case _ => fail("Expected an error, but got Ok")
            }
        } with handler Https {
            def request(_, resume) = 
                resume(Err(IoError(ConnectionFailed, "Simulated network failure")))
        } with botTokenHandler("test_token")

    @Test
    def testTokenPassedToGetUpdates(): Unit \ Assert =
        run {
            let _ = getUpdates(None);
            ()
        } with handler Https {
            def request(url, resume) = {
                String.contains(substr = "test_token", HttpRequest.url(url)) |> assertTrue;
                resume(Err(IoError(ConnectionFailed, "Simulated network failure")))
            }
        } with botTokenHandler("test_token")

    @Test
    def testOffsetPassedToGetUpdate(): Unit \ Assert = 
        run {
            let _ = getUpdates(Some(123i64));
            ()
        } with handler Https {
            def request(url, resume) = {
                String.contains(substr = "offset=123", HttpRequest.url(url)) |> assertTrue;
                resume(Err(IoError(ConnectionFailed, "Simulated network failure")))
            }
        } with botTokenHandler("test_token")

    @Test
    def testOffsetNotPassedToGetUpdateWhenNone(): Unit \ Assert = 
        run {
            let _ = getUpdates(None);
            ()
        } with handler Https {
            def request(url, resume) = {
                not String.contains(substr = "offset=", HttpRequest.url(url)) |> assertTrue;
                resume(Err(IoError(ConnectionFailed, "Simulated network failure")))
            }
        } with botTokenHandler("test_token")

    @Test
    def testGetUpdatesReceivedNonParseableBody(): Unit \ Assert = 
       run {
           match getUpdates(None) {
               case Err(Error.UnexpectedResponse(_)) => ()
               case _ => fail("Got OK or wrong error type, expected UnexpectedResponse")
           }
       } with httpHandlerWithBody("This is not JSON")
         with botTokenHandler("test_token")

    @Test
    def testGetUpdatesNoOkFieldInResponse(): Unit \ Assert = 
        run {
            getUpdates(None) |> assertEq(expected = Err(Error.ErrorResponse("Unknown status: no 'ok' field")))
        } with httpHandlerWithBody("{\"description\": \"Test error description\"}")
          with botTokenHandler("test_token")

    @Test
    def testGetUpdatesOkFieldNotBoolean(): Unit \ Assert = 
        run {
            getUpdates(None) |> assertEq(expected = Err(Error.ErrorResponse("Unknown status: 'ok' field is not a boolean")))
        } with httpHandlerWithBody("{\"ok\": \"not_a_boolean\", \"description\": \"Test error description\"}")
          with botTokenHandler("test_token")

    @Test
    def testGetUpdatesNotOkStatusAndValidDescription(): Unit \ Assert = 
        run {
            getUpdates(None) |> assertEq(expected = Err(Error.ErrorResponse("Test error description")))
        } with httpHandlerWithBody("{\"ok\": false, \"description\": \"Test error description\"}")
          with botTokenHandler("test_token")

    @Test
    def testGetUpdatesNotOkStatusAndNoDescriptionField(): Unit \ Assert = 
        run {
            getUpdates(None) |> assertEq(expected = Err(Error.ErrorResponse("Failed response, but no description")))
        } with httpHandlerWithBody("{\"ok\": false}")
          with botTokenHandler("test_token")

    @Test
    def testGetUpdatesNotOkStatusAndInvalidDescriptionField(): Unit \ Assert =
        run {
            getUpdates(None) |> assertEq(expected = Err(Error.ErrorResponse("Failed response, unable to decode description")))
        } with httpHandlerWithBody("{\"ok\": false, \"description\": 123}")
          with botTokenHandler("test_token")

    @Test
    def testGetUpdatesHasResultsAsNotArray(): Unit \ Assert = 
        run {
            match getUpdates(None) {
                // TODO Path, message?
                case Err(Error.UnexpectedResponse(JsonError.Decode(_, _))) => ()
                case _ => fail("Got OK or wrong error type or wrong description, expected ErrorResponse")
            }
        } with httpHandlerWithBody("{\"ok\": true, \"result\": {\"update_id\": 123}}")
          with botTokenHandler("test_token")

    @Test
    def testGetTwoUpdatesFromValidResponse(): Unit \ Assert = 
        run {
            match getUpdates(None) {
                case Ok(list) => assertEq(expected = 2, List.length(list))
                case _ => fail("Expected Ok with two updates")
            }
        } with httpHandlerWithBody("{\"ok\": true, \"result\": [${textUpdateJsonString(123i64, "Hello, world!", 1i64)}, ${textUpdateJsonString(456i64, "Hello, world!", 2i64)}] }")
          with botTokenHandler("test_token")

    @Test
    def testGetThreeUpdatesFromValidResponse(): Unit \ Assert = 
        run {
            match getUpdates(None) {
                case Ok(list) => assertEq(expected = 3, List.length(list))
                case _ => fail("Expected Ok with three updates")
            }
        } with httpHandlerWithBody("{\"ok\": true, \"result\": [${textUpdateJsonString(123i64, "Hello, world!", 1i64)}, ${textUpdateJsonString(456i64, "Hello, world!", 2i64)}, ${textUpdateJsonString(789i64, "Hello, world!", 3i64)}] }")
          with botTokenHandler("test_token")

    @Test
    def testGetUpdatesParsesTextMessage(): Unit \ Assert = 
        run {
            getUpdates(None) |> assertEq(expected = Ok(List#{TelegramUpdate.TextMessage({updateId = 123i64, message = "Hello, world!", chatId = 453i64})}))
        } with httpHandlerWithBody("{\"ok\": true, \"result\": [${textUpdateJsonString(123i64, "Hello, world!", 453i64)}] }")
          with botTokenHandler("test_token")
}
