abstract class BaseError implements Exception{
  final String err;

  BaseError(this.err);
}

class CouldNotReachOresults extends BaseError{
  CouldNotReachOresults(): super("Couldn't reach oresults.eu server");

}

class EventDoesNotExists extends BaseError{
  EventDoesNotExists(): super("Event doesn't exists");
}

class UploadToEventFailed extends BaseError{

  UploadToEventFailed(super.err);
}

class SiDroidResultsServiceNotRunning extends BaseError {
  SiDroidResultsServiceNotRunning(): super("SiDroid result service not running!");
}

class FetchResultsFromSiDroidFailed extends BaseError{
  FetchResultsFromSiDroidFailed(super.err);
}