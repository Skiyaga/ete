"""
Tree-related operations.

Sorting, changing the root to a node, moving branches, removing (prunning)...
"""

import random
from collections import namedtuple, deque


def sort(tree, key=None, reverse=False):
    """Sort the tree in-place."""
    key = key or (lambda node: (node.size[1], node.size[0], node.name))

    for node in tree.traverse('postorder'):
        node.children.sort(key=key, reverse=reverse)


def set_outgroup(node, bprops=None):
    """Reroot the tree at the given outgroup node.

    The original root node will be used as the new root node, so any
    reference to it in the code will still be valid.

    :param node: Node where to set root (future first child of the root).
    :param bprops: List of branch properties (other than "dist" and "support").
    """
    old_root = node.root
    positions = node.id  # child positions from root to node (like [1, 0, ...])

    assert_root_consistency(old_root, bprops)
    assert node != old_root, 'cannot set the absolute tree root as outgroup'

    # Make a new node to replace the old root.
    replacement = old_root.__class__()  # could be Tree() or PhyloTree(), etc.

    children = old_root.remove_children()
    replacement.add_children(children)  # take its children

    # Now we can insert the old root, which has no children, in its new place.
    insert_intermediate(node, old_root, bprops)

    root = replacement  # current root, which will change in each iteration
    for child_pos in positions:
        root = rehang(root, child_pos, bprops)

    if len(replacement.children) == 1:
        join_branch(replacement)


def assert_root_consistency(root, bprops=None):
    """Raise AssertionError if the root node of a tree looks inconsistent."""
    assert root.dist in [0, None], 'root has a distance'

    for pname in ['support'] + (bprops or []):
        assert pname not in root.props, f'root has branch property: {pname}'

    if len(root.children) == 2:
        ch1, ch2 = root.children
        s1, s2 = ch1.props.get('support'), ch2.props.get('support')
        assert s1 == s2, 'inconsistent support at the root: %r != %r' % (s1, s2)


def rehang(root, child_pos, bprops):
    """Rehang node on its child at position child_pos and return it."""
    # root === child  ->  child === root
    child = root.pop_child(child_pos)

    child.add_child(root)

    swap_props(root, child, ['dist', 'support'] + (bprops or []))

    return child  # which is now the parent of its previous parent


def swap_props(n1, n2, props):
    """Swap properties between nodes n1 and n2."""
    for pname in props:
        p1 = n1.props.pop(pname, None)
        p2 = n2.props.pop(pname, None)
        if p1 is not None:
            n2.props[pname] = p1
        if p2 is not None:
            n1.props[pname] = p2


def insert_intermediate(node, intermediate, bprops=None):
    """Insert, between node and its parent, an intermediate node."""
    # == up ======= node  ->  == up === intermediate === node
    up = node.up

    pos_in_parent = up.children.index(node)  # save its position in parent
    up.children.pop(pos_in_parent)  # detach from parent

    intermediate.add_child(node)

    if 'dist' in node.props:  # split dist between the new and old nodes
        node.dist = intermediate.dist = node.dist / 2

    for prop in ['support'] + (bprops or []):  # copy other branch props if any
        if prop in node.props:
            intermediate.props[prop] = node.props[prop]

    up.children.insert(pos_in_parent, intermediate)  # put new where old was
    intermediate.up = up


def join_branch(node):
    """Substitute node for its only child."""
    # == node ==== child  ->  ====== child
    assert len(node.children) == 1, 'cannot join branch with multiple children'

    child = node.children[0]

    if 'support' in node.props and 'support' in child.props:
        assert node.support == child.support, \
            'cannot join branches with different support'

    if 'dist' in node.props:
        child.dist = (child.dist or 0) + node.dist  # restore total dist

    up = node.up
    pos_in_parent = up.children.index(node)  # save its position in parent
    up.children.pop(pos_in_parent)  # detach from parent
    up.children.insert(pos_in_parent, child)  # put child where the old node was
    child.up = up


def move(node, shift=1):
    """Change the position of the current node with respect to its parent."""
    # ╴up╶┬╴node     ->  ╴up╶┬╴sibling
    #     ╰╴sibling          ╰╴node
    assert node.up, 'cannot move the root'

    siblings = node.up.children

    pos_old = siblings.index(node)
    pos_new = (pos_old + shift) % len(siblings)

    siblings[pos_old], siblings[pos_new] = siblings[pos_new], siblings[pos_old]


def remove(node):
    """Remove the given node from its tree."""
    assert node.up, 'cannot remove the root'

    parent = node.up
    parent.remove_child(node)


# Functions that used to be defined inside tree.pyx.

def common_ancestor(nodes):
    """Return the last node common to the lineages of the given nodes.

    If the given nodes don't have a common ancestor, it will return None.

    :param nodes: List of nodes whose common ancestor we want to find.
    """
    if not nodes:
        return None

    curr = nodes[0]  # current node being the last common ancestor

    for node in nodes[1:]:
        lin_node = set(node.lineage())
        curr = next((n for n in curr.lineage() if n in lin_node), None)

    return curr  # which is now the last common ancestor of all nodes


def populate(tree, size, names_library=None, random_branches=False,
             dist_range=(0, 1), support_range=(0, 1)):
    """Populate tree with branches generating a random topology.

    All the nodes added will either be leaves or have two branches.

    :param size: Number of leaves to add. The necessary
        intermediate nodes will be created too.
    :param names_library: Collection (list or set) used to name leaves.
        If None, leaves will be named using short letter sequences.
    :param random_branches: If True, branch distances and support
        values will be randomized.
    :param dist_range: Range (tuple with min and max) of distances
        used to generate branch distances if random_branches is True.
    :param support_range: Range (tuple with min and max) of distances
        used to generate branch supports if random_branches is True.
    """
    assert names_library is None or len(names_library) >= size, \
        f'names_library too small ({len(names_library)}) for size {size}'

    NewNode = tree.__class__

    if len(tree.children) > 1:
        connector = NewNode()
        for ch in tree.get_children():
            ch.detach()
            connector.add_child(ch)
        root = NewNode()
        tree.add_child(connector)
        tree.add_child(root)
    else:
        root = tree

    next_deq = deque([root])  # will contain the current leaves
    for i in range(size - 1):
        p = next_deq.popleft() if random.randint(0, 1) else next_deq.pop()

        c1 = p.add_child()
        c2 = p.add_child()

        next_deq.extend([c1, c2])

        if random_branches:
            c1.dist = random.uniform(*dist_range)
            c2.dist = random.uniform(*dist_range)
            c1.support = random.uniform(*support_range)
            c2.support = random.uniform(*support_range)
        else:
            c1.dist = 1.0
            c2.dist = 1.0
            c1.support = 1.0
            c2.support = 1.0

    # Give names to leaves.
    if names_library is not None:
        for node, name in zip(next_deq, names_library):
            node.name = name
    else:
        chars = 'abcdefghijklmnopqrstuvwxyz'

        for i, node in enumerate(next_deq):
            # Create a short name corresponding to the index i.
            # 0: 'a', 1: 'b', ..., 25: 'z', 26: 'aa', 27: 'ab', ...
            name = ''
            while i >= 0:
                name = chars[i % len(chars)] + name
                i = i // len(chars) - 1

            node.name = name


def ladderize(tree, topological=False, reverse=False):
    """Sort branches according to the size of each partition.

    :param topological: If True, the distance between nodes will be the
        number of nodes between them (instead of the sum of branch lenghts).
    :param reverse: If True, sort with biggest partitions first.

    Example::

      t = Tree('(f,((d,((a,b),c)),e));')
      print(t)
      #   ╭╴f
      # ──┤     ╭╴d
      #   │  ╭──┤  ╭──┬╴a
      #   ╰──┤  ╰──┤  ╰╴b
      #      │     ╰╴c
      #      ╰╴e

      t.ladderize()
      print(t)
      # ──┬╴f
      #   ╰──┬╴e
      #      ╰──┬╴d
      #         ╰──┬╴c
      #            ╰──┬╴a
      #               ╰╴b
    """
    sizes = {}  # sizes of the nodes

    # Key function for the sort order. Sort by size, then by # of children.
    key = lambda node: (sizes[node], len(node.children))

    # Distance function (branch length to consider for each node).
    dist = ((lambda node: 1) if topological else
            (lambda node: float(node.props.get('dist', 1))))

    for node in tree.traverse('postorder'):
        if node.is_leaf:
            sizes[node] = dist(node)
        else:
            node.children.sort(key=key, reverse=reverse)  # time to sort!

            sizes[node] = dist(node) + max(sizes[n] for n in node.children)

            for n in node.children:
                sizes.pop(n)  # free memory, no need to keep all the sizes


def to_ultrametric(tree, topological=False):
    """Convert tree to ultrametric (all leaves equidistant from root)."""
    tree.dist = tree.dist or 0  # covers common case of not having dist set

    update_sizes_all(tree)  # so node.size[0] are distances to leaves

    dist_full = tree.size[0]  # original distance from root to furthest leaf

    if (topological or dist_full <= 0 or
        any(node.dist is None for node in tree.traverse())):
        # Ignore original distances and just use the tree topology.
        for node in tree.traverse():
            node.dist = 1 if node.up else 0
        update_sizes_all(tree)
        dist_full = dist_full if dist_full > 0 else tree.size[0]

    for node in tree.traverse():
        if node.dist > 0:
            d = sum(n.dist for n in node.ancestors())
            node.dist *= (dist_full - d) / node.size[0]


# Traversing the tree.

# Position on the tree: current node, number of visited children.
TreePos = namedtuple('TreePos', 'node nch')

class Walker:
    """Represents the position when traversing a tree."""

    def __init__(self, root):
        self.visiting = [TreePos(node=root, nch=0)]
        # will look like: [(root, 2), (child2, 5), (child25, 3), (child253, 0)]
        self.descend = True

    def go_back(self):
        self.visiting.pop()
        if self.visiting:
            node, nch = self.visiting[-1]
            self.visiting[-1] = TreePos(node, nch + 1)
        self.descend = True

    @property
    def node(self):
        return self.visiting[-1].node

    @property
    def node_id(self):
        return tuple(branch.nch for branch in self.visiting[:-1])

    @property
    def first_visit(self):
        return self.visiting[-1].nch == 0

    @property
    def has_unvisited_branches(self):
        node, nch = self.visiting[-1]
        return nch < len(node.children)

    def add_next_branch(self):
        node, nch = self.visiting[-1]
        self.visiting.append(TreePos(node=node.children[nch], nch=0))


def walk(tree):
    """Yield an iterator as it traverses the tree."""
    it = Walker(tree)  # node iterator
    while it.visiting:
        if it.first_visit:
            yield it

            if it.node.is_leaf or not it.descend:
                it.go_back()
                continue

        if it.has_unvisited_branches:
            it.add_next_branch()
        else:
            yield it
            it.go_back()


# Size-related functions.

def update_sizes_all(tree):
    """Update sizes of all the nodes in the tree."""
    for node in tree.children:
        update_sizes_all(node)
    update_size(tree)


def update_sizes_from(node):
    """Update the sizes from the given node to the root of the tree."""
    while node:
        update_size(node)
        node = node.up


def update_size(node):
    """Update the size of the given node."""
    sumdists, nleaves = get_size(node.children)
    dx = float(node.props.get('dist', 0 if node.up is None else 1)) + sumdists
    node.size = (dx, max(1, nleaves))


cdef (double, double) get_size(nodes):
    """Return the size of all the nodes stacked."""
    # The size of a node is (sumdists, nleaves) with sumdists the dist to
    # its furthest leaf (including itself) and nleaves its number of leaves.
    cdef double sumdists, nleaves

    sumdists = 0
    nleaves = 0
    for node in nodes:
        sumdists = max(sumdists, node.size[0])
        nleaves += node.size[1]

    return sumdists, nleaves


# Convenience (hackish) functions.

def maybe_convert_internal_nodes_to_support(tree):
    """Convert if possible the values in internal nodes to support values."""
    # Often someone loads a newick looking like  ((a,b)s1,(c,d)s2,...)
    # where s1, s2, etc. are support values, not names. But they use the
    # wrong newick parser. Well, this function tries to hackishly fix that.
    for node in tree.traverse():
        if not node.is_leaf and node.name:
            try:
                node.support = float(node.name)
                node.name = ''
            except ValueError:
                pass
