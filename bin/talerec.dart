import 'dart:io';
import 'dart:io' show Platform;
import 'dart:convert' show LineSplitter, base64, utf8;
import 'package:yaml/yaml.dart';

void main(List<String> arguments) {
  final execDir = Platform.environment['PWD'];
  final configContent = File('$execDir/talerec.conf.yaml').readAsStringSync();
  final config = loadYaml(configContent);

  final dir = Directory(config['talesDir']);
  final files = dir
      .list(recursive: false)
      .where((fse) => fse is File)
      .map((f) => f as File);

  final fileContents = files.map((file) {
    return file.readAsStringSync();
  });

  final hashPattern = RegExp(r'#+\s');
  final dashPattern = RegExp(r'-+\s');
  final actorPattern = RegExp(r'^\*(.*)\*として');
  final usecasePattern = RegExp(r'、\*(.*)\*を行いたい');
  final reasonPattern = RegExp(r'なぜなら\*(.*)\*だ?からだ');

  var contexts = fileContents.map((content) {
    var contextName;
    var actorName;
    var usecaseName;
    var reason;
    var descriptions = <String>[];
    LineSplitter.split(content).forEach((line) {
      if (line.startsWith('##')) {
        var con = line.replaceFirst(hashPattern, '');
        actorName = actorPattern.firstMatch(con).group(1);
        usecaseName = usecasePattern.firstMatch(con).group(1);
        reason = reasonPattern.firstMatch(con)?.group(1) ?? '';
      } else if (line.startsWith('#')) {
        contextName = line.replaceFirst(hashPattern, '');
      } else if (line.startsWith('-')) {
        descriptions.add(line.replaceFirst(dashPattern, ''));
      }
    });
    return Context(contextName, usecaseName, actorName, reason, descriptions);
  }).toList();

  contexts.then((ctxs) {
    print('@startuml');
    print('left to right direction');
    ctxs.forEach((ctx) => print(ctx.toPlatUmlString()));
    print('@enduml');
  });
}

class Context {
  final String contextName;
  final String usecaseName;
  final String actorName;
  final String reason;
  final List<String> descriptions;

  Context(this.contextName, this.usecaseName, this.actorName, this.reason,
      this.descriptions);

  String toPlatUmlString() {
    var noteContent = descriptions.map((s) => '- $s').join('\n');
    return '''
package $contextName {
usecase "$usecaseName" as ${_base64(usecaseName)}
note top of (${_base64(usecaseName)})
$noteContent
end note
}
actor "$actorName" as ${_base64(actorName)}
${_base64(actorName)} --> ${_base64(usecaseName)}
''';
  }

  String _base64(String s) => base64.encode(utf8.encode(s));
}
