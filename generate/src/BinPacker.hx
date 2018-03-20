// Translated from https://github.com/jakesgordon/bin-packing/blob/master/js/packer.js
@:structInit
class Node {
    public var x: Float;
    public var y: Float;
    public var w: Float;
    public var h: Float;

    public var used = false;
    public var down: Node;
    public var right: Node;

    public function new(x: Float, y: Float, w: Float, h: Float) {
        this.x = x;
        this.y = y;
        this.w = w;
        this.h = h;
    }
}

class BinPacker {

    public static function fit(blocks: Array<{w: Float, h: Float}>, w: Float, h: Float) {
        var sortedBlocks = blocks.copy();
        sortedBlocks.sort((a, b) -> {
            var am = Math.max(a.w, a.h);
            var bm = Math.max(b.w, b.h);
            am > bm ? 1 : -1;
        });

        var fits = new Array<Null<{x: Float, y: Float, w: Float, h: Float}>>();

        var root = new Node(0, 0, w, h);

        for (block in sortedBlocks) {
            var node = findNode(root, block.w, block.h);
            fits[blocks.indexOf(block)] = node != null ? splitNode(node, block.w, block.h) : null;
        }
        return fits;
    }

    static function findNode(parent: Node, w: Float, h: Float) {
        if (parent.used) {
            var right = findNode(parent.right, w, h);
            return right != null ? right : findNode(parent.down, w, h);
        } else if ((w <= parent.w) && (h <= parent.h)) {
            return parent;
        }
        return null;
    }

    static function splitNode(node: Node, w: Float, h: Float) {
        node.used = true;
        node.down  = { x: node.x,     y: node.y + h, w: node.w,     h: node.h - h };
        node.right = { x: node.x + w, y: node.y,     w: node.w - w, h: h          };
        return node;
    }

}