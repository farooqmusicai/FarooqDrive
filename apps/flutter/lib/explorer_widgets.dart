import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'drive_controller.dart';
import 'models.dart';
import 'native_file_icon.dart';

const explorerViewLabels = <String, String>{
  'extraLarge': 'Extra large icons',
  'icons': 'Large icons',
  'medium': 'Medium icons',
  'small': 'Small icons',
  'list': 'List',
  'details': 'Details',
  'tiles': 'Tiles',
  'content': 'Content',
};

class CloudDragSource extends StatelessWidget {
  const CloudDragSource({super.key, required this.controller, required this.item, required this.child});
  final DriveController controller;
  final DriveItem item;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedKeys.contains(controller.keyOf(item)) ? controller.selectedItems : <DriveItem>[];
    final selection = selected.isEmpty ? [item] : selected;
    return Draggable<List<DriveItem>>(
      hitTestBehavior: HitTestBehavior.opaque,
      data: List.unmodifiable(selection), maxSimultaneousDrags: controller.loading ? 0 : 1,
      feedback: Material(elevation: 6, borderRadius: BorderRadius.circular(8), child: Padding(
        padding: const EdgeInsets.all(12), child: Text('${selection.length} item(s) · ${item.name}'))),
      childWhenDragging: Opacity(opacity: .4, child: child), child: child,
    );
  }
}

class CloudDropTarget extends StatelessWidget {
  const CloudDropTarget({super.key, required this.controller, required this.accountId, required this.path, required this.child});
  final DriveController controller;
  final String accountId;
  final List<FolderCrumb> path;
  final Widget child;
  @override
  Widget build(BuildContext context) => DragTarget<List<DriveItem>>(
    onWillAcceptWithDetails: (details) => !controller.loading && path.isNotEmpty &&
      !details.data.any((item) => item.accountId == accountId && item.id == path.last.id),
    onAcceptWithDetails: (details) async {
      final mode = await showDialog<ClipboardMode>(context: context, builder: (context) => AlertDialog(
        title: const Text('Copy or move here?'),
        content: Text('${details.data.length} item(s) → ${controller.accountById(accountId)?.email}\n${path.map((e) => e.name).join(' / ')}\n\nMove copies and verifies first, then asks separately before source cleanup.'),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ClipboardMode.copy), child: const Text('Copy')),
          TextButton(onPressed: () => Navigator.pop(context, ClipboardMode.move), child: const Text('Move')),
        ],
      ));
      if (mode == null || controller.loading) return;
      await controller.navigateTree(accountId, path);
      controller.clipboard = DriveClipboard(mode, details.data);
      await controller.paste();
    },
    builder: (context, candidates, rejected) => DecoratedBox(
      decoration: BoxDecoration(color: candidates.isEmpty ? null : Colors.blue.withValues(alpha: .08),
        border: Border.all(color: candidates.isEmpty ? Colors.transparent : Colors.blueAccent, width: 2)), child: child),
  );
}

/// Loading is scoped to the expanded directory, never an account-wide scan.
class DriveTree extends StatefulWidget {
  const DriveTree({super.key, required this.controller, required this.account, required this.child});
  final DriveController controller;
  final DriveAccount account;
  final Widget child;
  @override
  State<DriveTree> createState() => _DriveTreeState();
}
class _DriveTreeState extends State<DriveTree> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final api = widget.controller.apiFor(widget.account);
    final path = [FolderCrumb(api.rootFolderId, api.rootFolderLabel)];
    return Column(children: [
      CloudDropTarget(controller: widget.controller, accountId: widget.account.id, path: path,
        child: Row(children: [
          IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 24), iconSize: 18,
            color: Colors.white70, tooltip: expanded ? 'Collapse folders' : 'Expand folders',
            onPressed: () => setState(() => expanded = !expanded), icon: Icon(expanded ? Icons.expand_more : Icons.chevron_right)),
          Expanded(child: widget.child),
        ])),
      if (expanded) _TreeChildren(controller: widget.controller, account: widget.account, path: path),
    ]);
  }
}

class _TreeChildren extends StatefulWidget {
  const _TreeChildren({super.key, required this.controller, required this.account, required this.path});
  final DriveController controller;
  final DriveAccount account;
  final List<FolderCrumb> path;
  @override
  State<_TreeChildren> createState() => _TreeChildrenState();
}
class _TreeChildrenState extends State<_TreeChildren> {
  late Future<List<DriveItem>> children;
  late int revision;
  final Set<String> expanded = {};
  void load() {
    revision = widget.controller.treeRevision;
    children = widget.controller.apiFor(widget.account).listFolder(widget.account, widget.path.last.id);
  }
  @override
  void initState() { super.initState(); load(); }
  @override
  void didUpdateWidget(covariant _TreeChildren oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (revision != widget.controller.treeRevision) load();
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<DriveItem>>(
    future: children, builder: (context, snapshot) {
      if (snapshot.hasError) return TextButton(onPressed: () => setState(load), child: const Text('Could not load · Retry'));
      if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
      if (snapshot.data!.isEmpty) return const Text('Empty folder', style: TextStyle(color: Colors.white54, fontSize: 11));
      final items = List<DriveItem>.of(snapshot.data!)..sort((a,b) => a.isFolder != b.isFolder ? (a.isFolder ? -1 : 1) : a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return Column(children: [for (final item in items) ...[
        _row(context, item),
        if (item.isFolder && expanded.contains(item.id)) _TreeChildren(
          key: ValueKey(item.id), controller: widget.controller, account: widget.account,
          path: [...widget.path, FolderCrumb(item.id, item.name)]),
      ]]);
    },
  );
  Widget _row(BuildContext context, DriveItem item) {
    final path = [...widget.path, FolderCrumb(item.id, item.name)];
    final locatedItem = item.copyWithLocation(
      widget.path.map((crumb) => crumb.name).join(' / '),
    );
    final row = Padding(padding: EdgeInsets.only(left: (widget.path.length * 9).clamp(0, 45).toDouble()),
      child: Row(children: [
        if (item.isFolder) SizedBox(width: 22, child: IconButton(padding: EdgeInsets.zero, iconSize: 16,
          color: Colors.white70, onPressed: () => setState(() { expanded.contains(item.id) ? expanded.remove(item.id) : expanded.add(item.id); }),
          icon: Icon(expanded.contains(item.id) ? Icons.expand_more : Icons.chevron_right)))
        else const SizedBox(width: 22),
        NativeFileIcon(fileName: item.name, isFolder: item.isFolder, size: 16),
        const SizedBox(width: 4),
        Expanded(child: Tooltip(message: item.name, child: InkWell(
          onTap: widget.controller.loading ? null : () async {
            if (item.isFolder) {
              await widget.controller.navigateTree(widget.account.id, path);
            } else {
              widget.controller.selectOnly(locatedItem);
            }
          },
          onDoubleTap: widget.controller.loading || item.isFolder ? null : () async {
            final link = item.webViewLink;
            if (link == null || link.isEmpty) return;
            final opened = await launchUrl(Uri.parse(link), mode: LaunchMode.platformDefault, webOnlyWindowName: '_blank');
            if (opened) await widget.controller.recordFileOpened(item);
          },
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12)))))),
      ]));
    final drag = CloudDragSource(controller: widget.controller, item: item, child: row);
    return item.isFolder ? CloudDropTarget(controller: widget.controller, accountId: widget.account.id, path: path, child: drag) : drag;
  }
}
