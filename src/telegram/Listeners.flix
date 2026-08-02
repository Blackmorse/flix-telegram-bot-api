mod TelegramApi.Receiver.Listeners {
    use TelegramApi.Models.{WithUpdateId, TelegramUpdate, Error, TelegramBotToken}
    use TelegramApi.Receiver.{TelegramHttpReceiver, getUpdates};
    use Net.Https;

    pub eff TelegramUpdatesListener {
        def listenToUpdates(): Result[Error, Unit]
    }

    pub def runWithChannelLongPolling(sender: Sender[TelegramUpdate], f: Unit -> a \ ef): a \ (ef - TelegramUpdatesListener) + TelegramBotToken + Https + Chan = 
        run {
           f()
        } with runWithChannelHttpLoopUpdateListener(sender)
          with handler TelegramHttpReceiver {
            def fetchUpdates(offset, resume) = {
                getUpdates(offset) |> resume
            }
        }

    def runWithChannelHttpLoopUpdateListener(sender: Sender[TelegramUpdate], f: Unit -> a \ ef): a \ (ef - TelegramUpdatesListener) + TelegramHttpReceiver + Chan =
        run {
            f()
        } with handler TelegramUpdatesListener {
            def listenToUpdates(resume) = resume(runHttpLoopWithChannelHandler(sender, None, 0))
        }

    def maxErrorsInARow(): Int32 = 5i32

    @Tailrec
    def runHttpLoopWithChannelHandler(sender: Sender[TelegramUpdate], offset: Option[Int64], errorInARow: Int32): Result[Error, Unit] \ Chan + TelegramHttpReceiver =
        match TelegramHttpReceiver.fetchUpdates(offset) {
            case Ok(updates) =>
                List.forEach(update -> Channel.send(update, sender), updates);
                let next = updates |> List.map(WithUpdateId.getUpdateId) 
                    |> List.maximum 
                    |> Option.map(id -> id + 1i64);
                runHttpLoopWithChannelHandler(sender, next, 0)
            case Err(Error.NoUpdatesFound) => runHttpLoopWithChannelHandler(sender, offset, 0)
            case Err(_) if errorInARow < maxErrorsInARow() => runHttpLoopWithChannelHandler(sender, offset, errorInARow + 1)
            case Err(err) => Err(err)
        }
}

