package vshaxe.dependencyExplorer;

import haxe.io.Path;
import sys.FileSystem;
import vscode.Uri;

enum NodeType {
    File;
    Folder;
    Haxelib;
    StandardLibrary;
}

class Node extends TreeItem {
    public var path(default,null):String;
    public var type(default,null):NodeType;
    public var isDirectory(get,never):Bool;
    public var children(get,null):Array<Node>;

    public function new(label:String, path:String, ?type:NodeType) {
        super(label);
        resourceUri = Uri.file(path);
        this.path = path;
        this.type = type;

        if (this.type == null) {
            this.type = if (FileSystem.isDirectory(path)) Folder else File;
        }

        if (isDirectory) {
            collapsibleState = Collapsed;
            contextValue = "folder";
        } else {
            contextValue = "file." + Path.extension(path);
        }

        command = {
            command: Dependencies_SelectNode,
            arguments: [this],
            title: "Open File"
        };
    }

    inline function get_isDirectory():Bool {
        return type != File;
    }

    public static function sort(nodes:Array<Node>) {
        haxe.ds.ArraySort.sort(nodes, (c1, c2) -> {
            function compare(a:String, b:String) {
                a = a.toLowerCase();
                b = b.toLowerCase();
                if (a < b) return -1;
                if (a > b) return 1;
                return 0;
            }

            if (c1.isDirectory && c2.isDirectory) {
                return compare(c1.label, c2.label);
            } else if (c1.isDirectory) {
                return -1;
            } else if (c2.isDirectory) {
                return 1;
            } else {
                return compare(c1.label, c2.label);
            }
        });
    }

    public function collapse() {
        if (collapsibleState != None) {
            collapsibleState = Collapsed;
        }
    }

    public function refresh() {
        if (!isDirectory || children == null) {
            return;
        }

        var newChildren = [];
        forEachChild((file, path) -> {
            var existingNode = null;
            if (children != null) {
                existingNode = children.find(node -> node.label == file);
            }

            if (existingNode != null) {
                existingNode.refresh();
                newChildren.push(existingNode);
            } else {
                newChildren.push(new Node(file, path));
            }
        });
        sort(newChildren);
        children = newChildren;
    }

    public function toggleState() {
        collapsibleState = if (collapsibleState == Collapsed) Expanded else Collapsed;
    }

    function get_children():Array<Node> {
        if (children == null) {
            children = createChildren();
        }
        return children;
    }

    function createChildren() {
        if (!isDirectory) {
            return [];
        }

        var children = [];
        forEachChild((file, path) -> children.push(new Node(file, path)));
        sort(children);
        return children;
    }

    function forEachChild(f:String->String->Void) {
        for (file in FileSystem.readDirectory(path)) {
            if (!isExcluded(file)) {
                f(file, '$path/$file');
            }
        }
    }

    function isExcluded(file:String):Bool {
        // the proper way of doing this would be to check against the patterns in "files.exclude",
        // but then we'd need to include a lib for glob patterns...
        return file == ".git" || file == ".svn" || file == ".hg" || file == "CVS" || file == ".DS_Store";
    }
}
