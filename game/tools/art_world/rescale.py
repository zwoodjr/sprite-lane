"""Re-layout an existing Track A prop function at a larger size, drawn natively.

Takes the function's source, multiplies its LAYOUT literals (canvas size,
shape coordinates, loop bounds, radii) by k and re-runs it, so the kit's
shading, outline, seams, rivets, glints and AO are computed at 1 texel again.
This is not an upscale: 1 px details stay 1 px, tone bands are re-quantised
at the new size, noise clusters are re-rolled. Small literals (|v| < 4: pixel
offsets, line widths, tone indices), subscripts, floats < 4 (thresholds,
frequencies) and seed / noise arguments are left alone.

    from rescale import rescaled
    big_tank = rescaled(props_zone.oil_tank, 1.5)
"""
import ast
import inspect
import textwrap

# calls whose positional args are not layout (seeds, noise, thresholds)
SKIP_CALLS = {"blotch", "streaks", "_rust_and_holes", "blob_noise", "Random", "dents", "holes", "rust",
              "choice", "range_noise", "facets", "dome", "light_tone", "R", "max", "min", "round"}
SKIP_KW = {"seed", "scale", "thresh", "n", "flat", "tilt", "bias", "power", "jit", "period", "shade",
           "min_n", "hl", "ao", "selout", "orphans", "lo", "rim", "hollow", "top", "cap", "edge"}


class _K(ast.NodeTransformer):
    def __init__(self, k):
        self.k = k
        self.skip = 0

    def _scale(self, node):
        return ast.Call(func=ast.Name("_KS", ast.Load()), args=[node], keywords=[])

    def visit_Subscript(self, node):
        self.skip += 1
        self.generic_visit(node)
        self.skip -= 1
        return node

    def visit_Call(self, node):
        name = node.func.attr if isinstance(node.func, ast.Attribute) else (node.func.id if isinstance(node.func, ast.Name) else "")
        if name in SKIP_CALLS:
            # still scale the region / canvas args of blotch etc? they are masks, no literals
            self.skip += 1
            self.generic_visit(node)
            self.skip -= 1
            return node
        node.func = self.visit(node.func)
        node.args = [self.visit(a) for a in node.args]
        kws = []
        for kw in node.keywords:
            if kw.arg in SKIP_KW:
                kws.append(kw)
            else:
                kw.value = self.visit(kw.value)
                kws.append(kw)
        node.keywords = kws
        return node

    def visit_Constant(self, node):
        if self.skip or isinstance(node.value, bool) or not isinstance(node.value, (int, float)):
            return node
        v = node.value
        if abs(v) < 4 or v == 255:
            return node
        return self._scale(node)


def rescaled(fn, k, extra_globals=None):
    src = textwrap.dedent(inspect.getsource(fn))
    tree = ast.parse(src)
    fdef = tree.body[0]
    fdef.decorator_list = []
    fdef.body = [_K(k).visit(st) for st in fdef.body]
    # default args are layout too (wall_ruin(w=72, hgt=58 ...)) except seeds
    ast.fix_missing_locations(tree)
    g = dict(fn.__globals__)
    if extra_globals:
        g.update(extra_globals)
    kk = float(k)

    def _KS(v):
        r = v * kk
        return int(round(r)) if isinstance(v, int) else r
    g["_KS"] = _KS
    code = compile(tree, "<rescaled %s x%.2f>" % (fn.__name__, k), "exec")
    loc = {}
    exec(code, g, loc)
    return loc[fn.__name__]
