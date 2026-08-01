mod TelegramApi.Handler {
    use TelegramApi.Models.{TelegramUpdate, OutgoingMessage, TelegramBotToken}
    use Net.{Https, HttpRequest}
    use Util.Json.{Json, ToJson}

    pub eff UserMessageHandler {
        def handleMessage(message: TelegramUpdate): Unit
    }

    // no need to make public, there is no other options how to send messages now, apart for Https
    eff TelegramMessageSender {
        def sendMessage(message: OutgoingMessage): Result[Error, Unit]
    }

    pub def sendMessage(message: OutgoingMessage): Result[Error, Unit] \ Https + TelegramBotToken = 
        run {
            TelegramMessageSender.sendMessage(message)
        } with runWithHttpsMessageSender

    def runWithHttpsMessageSender(f: Unit -> a \ ef): a \ (ef - TelegramMessageSender) + Https + TelegramBotToken = 
        run {
            f()
        } with handler TelegramMessageSender {
          def sendMessage(message, resume) = {
              let botToken = TelegramBotToken.getToken();
              let body = ToJson.toJson(message) |> ToString.toString;
              let req = HttpRequest.post("https://api.telegram.org/${botToken}/sendMessage", body)
                  |> HttpRequest.withContentType("application/json");
              match Https.send(req) {
                  case Ok(_) => resume(Ok(()))
                  // TODO different error type
                  case Err(error) => resume(Err(Error.MessageSendError(error)))
              }
          }
        }

    pub enum Error {
        case MessageSendError(IoError)
    }
}
