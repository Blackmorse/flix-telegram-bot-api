mod TelegramApi.Models {
    use Util.Json
    use Util.Json.{FromJson, JsonError, JsonPath, ToJson, JNumber, JString, JObject}
    use Util.Json.JsonPath.JsonStep

    pub enum TelegramUpdate {
        case TextMessage({updateId = Int64, message = String, chatId = Int64})
        case OtherUpdate(Int64)
    }

    pub trait WithUpdateId[a] {
        pub def getUpdateId(a: a): Int64
    }

    instance WithUpdateId[TelegramUpdate] {
        pub def getUpdateId(update: TelegramUpdate): Int64 = match update {
            case TelegramUpdate.TextMessage({updateId | _}) => updateId
            case TelegramUpdate.OtherUpdate(updateId) => updateId
        }
    }

    // TODO: cover with tests
    instance Eq[TelegramUpdate] {
        pub def eq(x: TelegramUpdate, y: TelegramUpdate): Bool = match (x, y) {
            case (TelegramUpdate.TextMessage(recordX), TelegramUpdate.TextMessage(recordY)) => recordX#updateId == recordY#updateId and recordX#message == recordY#message and recordX#chatId == recordY#chatId
            case (TelegramUpdate.OtherUpdate(idX), TelegramUpdate.OtherUpdate(idY)) => idX == idY
            case _ => false
        }
    }

    instance ToString[TelegramUpdate] {
        pub def toString(x: TelegramUpdate): String = match x {
            case TelegramUpdate.TextMessage(record) => "TextMessage(updateId=${record#updateId}, message=${record#message}, chatId=${record#chatId})"
            case TelegramUpdate.OtherUpdate(id) => "OtherUpdate(updateId=${id})"
        }
    }

    pub eff TelegramBotToken {
        def getToken(): String
    }

    pub def runWithToken(token: String, f: Unit -> a \ ef): a \ (ef - TelegramBotToken) = 
        run {
            f()
        } with handler TelegramBotToken {
            def getToken(resume) = resume(token)
        }

    // TODO: cover with tests(?)
    instance FromJson[TelegramUpdate] {
        pub def fromJson(j: Json): Result[JsonError, TelegramUpdate] = 
            forM (
                updateId <- JsonExt.getAsInt64("update_id", j);
                message  <- JsonExt.getAsStringFromPath(JsonPath(JsonStep.Key("message") :: JsonStep.Key("text") :: Nil), j);
                chatId   <- JsonExt.getAsInt64FromPath(JsonPath(JsonStep.Key("message") :: JsonStep.Key("chat") :: JsonStep.Key("id") :: Nil), j)
                ) yield TelegramUpdate.TextMessage({updateId = updateId, message = message, chatId = chatId})
    }

    pub enum OutgoingMessage {
        case TextMessage({chatId = Int64, text = String})
    }

    instance ToJson[OutgoingMessage] {
        pub def toJson(x: OutgoingMessage): Json = match x {
            case OutgoingMessage.TextMessage({chatId, text}) => JObject(Map#{
                "chat_id" => JNumber(Int64.toBigDecimal(chatId)),
                "text"    => JString(text)
            })
        }
    }
}
