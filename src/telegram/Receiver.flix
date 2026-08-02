mod TelegramApi.Receiver {
    use Util.Json
    use Util.Json.{JsonError, parse, FromJson, JBool, JString, FromJson}
    use TelegramApi.Models.{TelegramUpdate, WithUpdateId, TelegramBotToken, Error}
    use Net.{Https, HttpRequest, HttpResponse}

    eff TelegramHttpReceiver {
        def fetchUpdates(offset: Option[Int64]): Result[Error, List[TelegramUpdate]]
    }
    
    def getUpdates(offset: Option[Int64]): Result[Error, List[TelegramUpdate]] \ { Https, TelegramBotToken } = 
        let offsetSuffix = match offset {
            case Some(o) => "&offset=${o}"
            case None => ""
        };
        let token = TelegramBotToken.getToken();
        let url = "https://api.telegram.org/${token}/getUpdates?timeout=30${offsetSuffix}";
        match Https.send(HttpRequest.get(url)) {
            case Ok(response) => match HttpResponse.body(response) |> parse {
                case Ok(json) => 
                    forM (
                        _       <- checkOkField(json);
                        results <- JsonExt.getAsArray("result", json) |> Result.map(Vector.toList) |> Result.mapErr(Error.UnexpectedResponse);
                        list    <- Result.traverse(FromJson.fromJson, results) |> Result.mapErr(Error.UnexpectedResponse)
                    ) yield list
                case Err(error) => Err(Error.UnexpectedResponse(error))
            }
            case Err(error) => Err(Error.NetworkError(error))
        }

    def checkOkField(json: Json): Result[Error, Json] = 
        match FromJson.getAtKey("ok", json) {
            case Ok(JBool(false)) => match FromJson.getAtKey("description", json) {
                case Ok(JString(desc)) => Err(Error.ErrorResponse(desc))
                case Ok(_) => Err(Error.ErrorResponse("Failed response, unable to decode description"))
                case Err(_) => Err(Error.ErrorResponse("Failed response, but no description"))
            }
            case Ok(JBool(true)) => Ok(json)
            case Ok(_) => Err(Error.ErrorResponse("Unknown status: 'ok' field is not a boolean"))
            case Err(_) => Err(Error.ErrorResponse("Unknown status: no 'ok' field"))
        }
}

