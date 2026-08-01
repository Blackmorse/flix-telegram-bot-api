mod TelegramApi.Receiver {
    use Util.Json
    use Util.Json.{JsonError, parse, FromJson, JBool, JString, FromJson}
    use TelegramApi.Models.{TelegramUpdate, WithUpdateId, TelegramBotToken}
    use Net.{Https, HttpRequest, HttpResponse}

    pub eff TelegramUpdatesListener {
        def listenToUpdates(): Result[Error, Unit]
    }

    eff TelegramHttpReceiver {
        def fetchUpdates(offset: Option[Int64]): Result[Error, List[TelegramUpdate]]
    }

    pub def runWithLongPollingLoop(rc: Region[r], handle: TelegramUpdate -> Unit \ { IO }, f: Unit -> a \ ef): a \ (ef - TelegramUpdatesListener) + TelegramBotToken + IO + Https =
        run {
            f()
        } with handler TelegramUpdatesListener {
            def listenToUpdates(resume) = {
                match runHttpLoopAsyncHandler(rc, handle, None) {
                    case Ok(_) => resume(Ok(()))
                    case Err(err) => resume(Err(err))
                }
            }
        } with handler TelegramHttpReceiver {
            def fetchUpdates(offset, resume) = {
                getUpdates(offset) |> resume
            }
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

    @Tailrec
    def runHttpLoopAsyncHandler(rc: Region[r], handle: TelegramUpdate -> Unit \ IO, offset: Option[Int64]): Result[Error, Int64] \ { TelegramHttpReceiver, IO} = 
        let updates = match TelegramHttpReceiver.fetchUpdates(offset) {
            case Ok(updates) => updates
            case Err(_) => Nil
        };
        List.forEach(update -> {
            spawn handle(update) @ rc;
            ()
        }, updates);
        let nextUpdate = updates |> List.map(WithUpdateId.getUpdateId) |> List.maximum |> Option.map(id -> id + 1i64);
        runHttpLoopAsyncHandler(rc, handle, nextUpdate)


    pub enum Error with Eq, ToString {
        case NetworkError(IoError),
        case NoUpdatesFound,
        case UnexpectedResponse(JsonError),
        case ErrorResponse(String)
    }
}

