mod TelegramApi.Receiver.Listeners.Tests {
    use TelegramApi.Models.{TelegramUpdate, Error};
    use TelegramApi.Receiver.{TelegramHttpReceiver};
    use TelegramApi.Receiver.Listeners.{runWithChannelHttpLoopUpdateListener, TelegramUpdatesListener}
    use Assert.assertEq;

    // TODO check: PoisonPill might be not neccessary
    type alias Update = Result[Error, List[TelegramUpdate]]
    enum Responses {
        case Response(Update),
        case PoisonPill
    }

    @Test
    def testChannelLoopReceivesUpdates(): Unit \ {Assert, Chan, NonDet} = region rc {
        let (sender, receiver) = Channel.unbuffered();
        spawn run {
            let _ = TelegramUpdatesListener.listenToUpdates();
            ()
        } with runWithChannelHttpLoopUpdateListener(sender)
          with handler TelegramHttpReceiver {
            def fetchUpdates(offset, resume) = match offset{
                case None => resume(Ok(TelegramUpdate.OtherUpdate(1i64) :: Nil))
                case Some(2i64) => resume(Ok(TelegramUpdate.OtherUpdate(2i64) :: TelegramUpdate.OtherUpdate(3i64) :: Nil))
                case _ => ()
            }
          } @ rc;
        Channel.recv(receiver) |> Assert.assertEq(expected = TelegramUpdate.OtherUpdate(1i64));
        Channel.recv(receiver) |> Assert.assertEq(expected = TelegramUpdate.OtherUpdate(2i64));
        Channel.recv(receiver) |> Assert.assertEq(expected = TelegramUpdate.OtherUpdate(3i64))
    }

    @Test
    def testChannelLoopReceiverStopsOnSixthError(): Unit \ {Assert, Chan, NonDet, IO} = region rc {
        let (sender, receiver) = Channel.unbuffered();
        let (responsesSender, responsesReceiver) = Channel.buffered(100);
        let (errorTrackerSender, errorTrackerReceiver) = Channel.buffered(100);
        responsesSender |> Channel.send(Responses.Response(Ok(TelegramUpdate.OtherUpdate(1i64) :: Nil)));
        List.range(1, 7) |> List.forEach(i -> responsesSender |> Channel.send(Responses.Response(Err(Error.ErrorResponse("Error ${i}")))));
        spawn {
            run {
                let result = TelegramUpdatesListener.listenToUpdates();
                Channel.send(result, errorTrackerSender);
                ()
            } with runWithChannelHttpLoopUpdateListener(sender)
              with handler TelegramHttpReceiver {
                def fetchUpdates(_, resume) = 
                    match Channel.recv(responsesReceiver) {
                        case Responses.Response(update) => resume(update)
                        case Responses.PoisonPill => ()
                    }
              }
            } @ rc;
        Channel.recv(receiver) |> Assert.assertEq(expected = TelegramUpdate.OtherUpdate(1i64));
        Channel.recv(errorTrackerReceiver) |> Assert.assertEq(expected = Err(Error.ErrorResponse("Error 6")))
    }

    @Test
    def testChannelLoopResetErrorNumberIfErrorsAreLessThenSix(): Unit \ { Assert, Chan, NonDet, IO } = region rc {
        let (sender, receiver) = Channel.unbuffered();
        let (responsesSender, responsesReceiver) = Channel.buffered(100);
        let (errorTrackerSender, errorTrackerReceiver) = Channel.buffered(100);
        responsesSender |> Channel.send(Responses.Response(Ok(TelegramUpdate.OtherUpdate(1i64) :: Nil)));
        List.range(1, 6) |> List.forEach(i -> responsesSender |> Channel.send(Responses.Response(Err(Error.ErrorResponse("Error ${i}")))));
        // Here counter of errors should be reset to 0
        responsesSender |> Channel.send(Responses.Response(Ok(TelegramUpdate.OtherUpdate(2i64) :: Nil)));
        List.range(6, 12) |> List.forEach(i -> responsesSender |> Channel.send(Responses.Response(Err(Error.ErrorResponse("Error ${i}")))));
        responsesSender |> Channel.send(Responses.PoisonPill);
        spawn {
            run {
                let result = TelegramUpdatesListener.listenToUpdates();
                Channel.send(result, errorTrackerSender);
                ()
            } with runWithChannelHttpLoopUpdateListener(sender)
              with handler TelegramHttpReceiver {
                def fetchUpdates(_, resume) = 
                    match Channel.recv(responsesReceiver) {
                        case Responses.Response(update) => resume(update)
                        case Responses.PoisonPill => ()
                    }
              }
            } @ rc;
        Channel.recv(receiver) |> Assert.assertEq(expected = TelegramUpdate.OtherUpdate(1i64));
        Channel.recv(receiver) |> Assert.assertEq(expected = TelegramUpdate.OtherUpdate(2i64));
        Channel.recv(errorTrackerReceiver) |> Assert.assertEq(expected = Err(Error.ErrorResponse("Error 11")))
    }

    @Test
    def testChannelShouldntTreatNoUpdatesAsAnError(): Unit \ { Assert, Chan, NonDet, IO } = region rc {
        let (sender, receiver) = Channel.unbuffered();
        let (responsesSender, responsesReceiver) = Channel.buffered(100);
        let (errorTrackerSender, errorTrackerReceiver) = Channel.buffered(100);
        responsesSender |> Channel.send(Responses.Response(Ok(TelegramUpdate.OtherUpdate(1i64) :: Nil)));
        List.range(1, 10) |> List.forEach(_ -> responsesSender |> Channel.send(Responses.Response(Err(Error.NoUpdatesFound))));
        List.range(11, 16) |> List.forEach(i -> responsesSender |> Channel.send(Responses.Response(Err(Error.ErrorResponse("Error ${i}")))));
        // NoUpdates should reset error counter to 0
        responsesSender |> Channel.send(Responses.Response(Err(Error.NoUpdatesFound)));
        responsesSender |> Channel.send(Responses.Response(Err(Error.ErrorResponse("Error 17"))));
        responsesSender |> Channel.send(Responses.PoisonPill);
        spawn {
            run {
                let result = TelegramUpdatesListener.listenToUpdates();
                Channel.send(result, errorTrackerSender);
                ()
            } with runWithChannelHttpLoopUpdateListener(sender)
              with handler TelegramHttpReceiver {
                def fetchUpdates(_, resume) = 
                    match Channel.recv(responsesReceiver) {
                        case Responses.Response(update) => resume(update)
                        case Responses.PoisonPill => ()
                    }
              }
            } @ rc;
        Channel.recv(receiver) |> Assert.assertEq(expected = TelegramUpdate.OtherUpdate(1i64));
        select {
            case _ <- recv(errorTrackerReceiver) => Assert.fail("Expected no error, but got one")
            case _                               => ()
        }
    }
}
