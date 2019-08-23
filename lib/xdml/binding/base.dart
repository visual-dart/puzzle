import '../app.dart';

class TempPayload {
  ComponentTreeNode node;
  SlotNode slot;
  int childIndex;
  bool isIf = false;
  bool isElse = false;
  bool isIfStatement = false;
  bool isIfElement = false;
  TempPayload(this.node, this.slot, this.childIndex);
}

enum TurnType { statement, element, node }

class Turn {
  TurnType type = TurnType.node;
  List<TempPayload> payload = [];

  Turn(this.payload);
}

class InsertResult {
  bool valid = false;
  dynamic value;
  InsertResult(this.valid, this.value);
}
