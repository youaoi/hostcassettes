#import <XCTest/XCTest.h>
#import "HostsMenu.h"
#import "Hosts.h"

// Forward-declare HostsMenuNode so tests can inspect the trie structure
@interface HostsMenuNode : NSObject
@property (nonatomic, strong) NSString *label;
@property (nonatomic, strong) Hosts *hosts;
@property (nonatomic, strong) NSMutableArray<NSString*> *childKeys;
@property (nonatomic, strong) NSMutableDictionary<NSString*, HostsMenuNode*> *children;
- (Hosts*)firstLeafHosts;
- (void)addChild:(HostsMenuNode*)child forKey:(NSString*)key;
@end

// Expose private methods for testing
@interface HostsMenu (Testing)
- (HostsMenuNode*)buildTrieFromHosts:(NSArray*)hostsArray;
- (void)compactNode:(HostsMenuNode*)node;
- (void)createMenuItemsFromNode:(HostsMenuNode*)node intoMenu:(NSMenu*)menu indentation:(BOOL)indentation;
@end

#pragma mark - Helpers

static Hosts* makeHosts(NSString *name) {
    NSString *tempDir = NSTemporaryDirectory();
    NSString *path = [tempDir stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"%@.hst", name]];
    [@"" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    Hosts *h = [[Hosts alloc] initWithPath:path];
    return h;
}

#pragma mark -

@interface HostsMenuTests : XCTestCase
@property (nonatomic, strong) NSMutableArray<NSString*> *tempPaths;
@end

@implementation HostsMenuTests

- (void)setUp {
    [super setUp];
    self.tempPaths = [NSMutableArray array];
}

- (void)tearDown {
    for (NSString *p in self.tempPaths) {
        [[NSFileManager defaultManager] removeItemAtPath:p error:NULL];
    }
    [super tearDown];
}

- (Hosts*)hostsWithName:(NSString*)name {
    Hosts *h = makeHosts(name);
    [self.tempPaths addObject:h.path];
    return h;
}

#pragma mark - buildTrieFromHosts

- (void)testBuildTrieSimpleName {
    // A name without "-" should create a single-level trie
    Hosts *h = [self hostsWithName:@"myhost"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h]];

    XCTAssertEqual([root.childKeys count], (NSUInteger)1);
    HostsMenuNode *child = root.children[@"myhost"];
    XCTAssertNotNil(child);
    XCTAssertEqualObjects(child.label, @"myhost");
    XCTAssertEqual(child.hosts, h);
    XCTAssertEqual([child.childKeys count], (NSUInteger)0);
}

- (void)testBuildTrieHyphenatedName {
    // "xxx-yyy" should create xxx -> yyy
    Hosts *h = [self hostsWithName:@"xxx-yyy"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h]];

    XCTAssertEqual([root.childKeys count], (NSUInteger)1);
    HostsMenuNode *xxx = root.children[@"xxx"];
    XCTAssertNotNil(xxx);
    XCTAssertNil(xxx.hosts);
    XCTAssertEqual([xxx.childKeys count], (NSUInteger)1);

    HostsMenuNode *yyy = xxx.children[@"yyy"];
    XCTAssertNotNil(yyy);
    XCTAssertEqual(yyy.hosts, h);
}

- (void)testBuildTrieSharedPrefix {
    // "xxx-yyy" and "xxx-zzz" should share the "xxx" node
    Hosts *h1 = [self hostsWithName:@"xxx-yyy"];
    Hosts *h2 = [self hostsWithName:@"xxx-zzz"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h1, h2]];

    XCTAssertEqual([root.childKeys count], (NSUInteger)1);
    HostsMenuNode *xxx = root.children[@"xxx"];
    XCTAssertNotNil(xxx);
    XCTAssertEqual([xxx.childKeys count], (NSUInteger)2);

    HostsMenuNode *yyy = xxx.children[@"yyy"];
    HostsMenuNode *zzz = xxx.children[@"zzz"];
    XCTAssertEqual(yyy.hosts, h1);
    XCTAssertEqual(zzz.hosts, h2);
}

- (void)testBuildTrieMultiLevel {
    // "a-b-c" should create a -> b -> c
    Hosts *h = [self hostsWithName:@"a-b-c"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h]];

    HostsMenuNode *a = root.children[@"a"];
    XCTAssertNotNil(a);
    HostsMenuNode *b = a.children[@"b"];
    XCTAssertNotNil(b);
    HostsMenuNode *c = b.children[@"c"];
    XCTAssertNotNil(c);
    XCTAssertEqual(c.hosts, h);
}

- (void)testBuildTrieInsertionOrder {
    // Child keys should preserve insertion order
    Hosts *h1 = [self hostsWithName:@"xxx-bbb"];
    Hosts *h2 = [self hostsWithName:@"xxx-aaa"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h1, h2]];

    HostsMenuNode *xxx = root.children[@"xxx"];
    XCTAssertEqualObjects(xxx.childKeys[0], @"bbb");
    XCTAssertEqualObjects(xxx.childKeys[1], @"aaa");
}

#pragma mark - compactNode

- (void)testCompactSingleChild {
    // "foo-bar" (single item) should compact to a single leaf with label "foo-bar"
    Hosts *h = [self hostsWithName:@"foo-bar"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h]];
    [menu compactNode:root];

    XCTAssertEqual([root.childKeys count], (NSUInteger)1);
    HostsMenuNode *child = root.children[root.childKeys[0]];
    XCTAssertEqualObjects(child.label, @"foo-bar");
    XCTAssertEqual(child.hosts, h);
    XCTAssertEqual([child.childKeys count], (NSUInteger)0);
}

- (void)testCompactDoesNotMergeWhenMultipleChildren {
    // "xxx-yyy" and "xxx-zzz" should keep "xxx" as a branch
    Hosts *h1 = [self hostsWithName:@"xxx-yyy"];
    Hosts *h2 = [self hostsWithName:@"xxx-zzz"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h1, h2]];
    [menu compactNode:root];

    XCTAssertEqual([root.childKeys count], (NSUInteger)1);
    HostsMenuNode *xxx = root.children[root.childKeys[0]];
    XCTAssertEqualObjects(xxx.label, @"xxx");
    XCTAssertNil(xxx.hosts);
    XCTAssertEqual([xxx.childKeys count], (NSUInteger)2);
}

- (void)testCompactMultiLevelSinglePath {
    // "a-b-c" (single item) should compact to "a-b-c"
    Hosts *h = [self hostsWithName:@"a-b-c"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h]];
    [menu compactNode:root];

    XCTAssertEqual([root.childKeys count], (NSUInteger)1);
    HostsMenuNode *child = root.children[root.childKeys[0]];
    XCTAssertEqualObjects(child.label, @"a-b-c");
    XCTAssertEqual(child.hosts, h);
}

- (void)testCompactPartialMerge {
    // "a-b-c" and "a-b-d" should compact "a-b" prefix but keep c and d separate
    // Result: root -> a -> b (with children c, d)
    // Since a has only one child (b), and b has two children, a stays.
    // Actually: a has one child b, but a is not a leaf, so a merges with b -> label "a"
    // Wait: let's think again. Trie: root -> a -> b -> {c, d}
    // compactNode on root: recurse into a. 
    //   compactNode on a: recurse into b.
    //     compactNode on b: recurse into c and d (leaves, no-op). b has 2 children, no merge.
    //   a has 1 child (b), a is not leaf -> merge. a.label = "a-b", a.children = {c, d}
    // root has 1 child. Root has no label, so root stays (root is virtual).
    Hosts *h1 = [self hostsWithName:@"a-b-c"];
    Hosts *h2 = [self hostsWithName:@"a-b-d"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h1, h2]];
    [menu compactNode:root];

    // Root should have one child with merged label
    XCTAssertEqual([root.childKeys count], (NSUInteger)1);
    HostsMenuNode *ab = root.children[root.childKeys[0]];
    XCTAssertEqualObjects(ab.label, @"a-b");
    XCTAssertNil(ab.hosts);
    XCTAssertEqual([ab.childKeys count], (NSUInteger)2);

    HostsMenuNode *c = ab.children[@"c"];
    HostsMenuNode *d = ab.children[@"d"];
    XCTAssertEqual(c.hosts, h1);
    XCTAssertEqual(d.hosts, h2);
}

- (void)testCompactPreservesLeafNode {
    // "a" and "a-b" both exist: "a" is a leaf AND has a child.
    // compactNode should NOT merge a with b because a is a leaf.
    Hosts *h1 = [self hostsWithName:@"a"];
    Hosts *h2 = [self hostsWithName:@"a-b"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h1, h2]];
    [menu compactNode:root];

    HostsMenuNode *a = root.children[root.childKeys[0]];
    XCTAssertEqualObjects(a.label, @"a");
    XCTAssertEqual(a.hosts, h1);
    XCTAssertEqual([a.childKeys count], (NSUInteger)1);

    HostsMenuNode *b = a.children[@"b"];
    XCTAssertEqual(b.hosts, h2);
}

#pragma mark - createMenuItemsFromNode (menu structure)

- (void)testMenuItemsNoHyphen {
    // Names without hyphens should produce flat menu items
    Hosts *h1 = [self hostsWithName:@"alpha"];
    Hosts *h2 = [self hostsWithName:@"beta"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h1, h2]];
    [menu compactNode:root];

    NSMenu *target = [[NSMenu alloc] init];
    [menu createMenuItemsFromNode:root intoMenu:target indentation:NO];

    XCTAssertEqual([target numberOfItems], 2);
    XCTAssertEqualObjects([[target itemAtIndex:0] title], @"alpha");
    XCTAssertEqualObjects([[target itemAtIndex:1] title], @"beta");
    XCTAssertNil([[target itemAtIndex:0] submenu]);
    XCTAssertNil([[target itemAtIndex:1] submenu]);
}

- (void)testMenuItemsWithSubmenu {
    // "xxx-yyy" and "xxx-zzz" should produce a submenu under "xxx"
    Hosts *h1 = [self hostsWithName:@"xxx-yyy"];
    Hosts *h2 = [self hostsWithName:@"xxx-zzz"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h1, h2]];
    [menu compactNode:root];

    NSMenu *target = [[NSMenu alloc] init];
    [menu createMenuItemsFromNode:root intoMenu:target indentation:NO];

    XCTAssertEqual([target numberOfItems], 1);
    NSMenuItem *parent = [target itemAtIndex:0];
    XCTAssertEqualObjects([parent title], @"xxx");
    XCTAssertNotNil([parent submenu]);

    NSMenu *sub = [parent submenu];
    XCTAssertEqual([sub numberOfItems], 2);
    XCTAssertEqualObjects([[sub itemAtIndex:0] title], @"yyy");
    XCTAssertEqualObjects([[sub itemAtIndex:1] title], @"zzz");
}

- (void)testMenuItemsSingleHyphenatedNoSubmenu {
    // "foo-bar" alone (no other "foo-*") should NOT produce a submenu
    Hosts *h = [self hostsWithName:@"foo-bar"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h]];
    [menu compactNode:root];

    NSMenu *target = [[NSMenu alloc] init];
    [menu createMenuItemsFromNode:root intoMenu:target indentation:NO];

    XCTAssertEqual([target numberOfItems], 1);
    NSMenuItem *item = [target itemAtIndex:0];
    XCTAssertEqualObjects([item title], @"foo-bar");
    XCTAssertNil([item submenu]);
}

- (void)testMenuItemsRecursiveSubmenu {
    // "a-b-c", "a-b-d", "a-e" should produce:
    // a (submenu)
    //   b (submenu)  -- "a-b" prefix compacted to "b" within a's submenu
    //     c
    //     d
    //   e
    Hosts *h1 = [self hostsWithName:@"a-b-c"];
    Hosts *h2 = [self hostsWithName:@"a-b-d"];
    Hosts *h3 = [self hostsWithName:@"a-e"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h1, h2, h3]];
    [menu compactNode:root];

    NSMenu *target = [[NSMenu alloc] init];
    [menu createMenuItemsFromNode:root intoMenu:target indentation:NO];

    // Top level: just "a"
    XCTAssertEqual([target numberOfItems], 1);
    NSMenuItem *aItem = [target itemAtIndex:0];
    XCTAssertEqualObjects([aItem title], @"a");
    XCTAssertNotNil([aItem submenu]);

    NSMenu *aSub = [aItem submenu];
    XCTAssertEqual([aSub numberOfItems], 2);

    // First: "b" submenu
    NSMenuItem *bItem = [aSub itemAtIndex:0];
    XCTAssertEqualObjects([bItem title], @"b");
    XCTAssertNotNil([bItem submenu]);
    NSMenu *bSub = [bItem submenu];
    XCTAssertEqual([bSub numberOfItems], 2);
    XCTAssertEqualObjects([[bSub itemAtIndex:0] title], @"c");
    XCTAssertEqualObjects([[bSub itemAtIndex:1] title], @"d");

    // Second: "e" leaf
    NSMenuItem *eItem = [aSub itemAtIndex:1];
    XCTAssertEqualObjects([eItem title], @"e");
    XCTAssertNil([eItem submenu]);
}

- (void)testMenuItemsMixedFlatAndGrouped {
    // Mix of groupable and non-groupable names
    // "standalone", "env-dev", "env-stg"
    Hosts *h1 = [self hostsWithName:@"standalone"];
    Hosts *h2 = [self hostsWithName:@"env-dev"];
    Hosts *h3 = [self hostsWithName:@"env-stg"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h1, h2, h3]];
    [menu compactNode:root];

    NSMenu *target = [[NSMenu alloc] init];
    [menu createMenuItemsFromNode:root intoMenu:target indentation:NO];

    XCTAssertEqual([target numberOfItems], 2);

    // "standalone" - flat
    NSMenuItem *standaloneItem = [target itemAtIndex:0];
    XCTAssertEqualObjects([standaloneItem title], @"standalone");
    XCTAssertNil([standaloneItem submenu]);

    // "env" - submenu with dev, stg
    NSMenuItem *envItem = [target itemAtIndex:1];
    XCTAssertEqualObjects([envItem title], @"env");
    XCTAssertNotNil([envItem submenu]);
    XCTAssertEqual([[envItem submenu] numberOfItems], 2);
}

#pragma mark - Active state

- (void)testActiveHostCheckmark {
    // Active host should have checkmark (NSControlStateValueOn)
    Hosts *h1 = [self hostsWithName:@"xxx-yyy"];
    Hosts *h2 = [self hostsWithName:@"xxx-zzz"];
    [h2 setActive:YES];

    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h1, h2]];
    [menu compactNode:root];

    NSMenu *target = [[NSMenu alloc] init];
    [menu createMenuItemsFromNode:root intoMenu:target indentation:NO];

    NSMenu *sub = [[target itemAtIndex:0] submenu];
    XCTAssertEqual([[sub itemAtIndex:0] state], NSControlStateValueOff);
    XCTAssertEqual([[sub itemAtIndex:1] state], NSControlStateValueOn);
}

#pragma mark - Branch + leaf (node is both leaf and branch)

- (void)testBranchAndLeafSubmenu {
    // "a" and "a-b" both exist: "a" should be a submenu with "a" itself at top + separator
    Hosts *h1 = [self hostsWithName:@"a"];
    Hosts *h2 = [self hostsWithName:@"a-b"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h1, h2]];
    [menu compactNode:root];

    NSMenu *target = [[NSMenu alloc] init];
    [menu createMenuItemsFromNode:root intoMenu:target indentation:NO];

    XCTAssertEqual([target numberOfItems], 1);
    NSMenuItem *aItem = [target itemAtIndex:0];
    XCTAssertEqualObjects([aItem title], @"a");
    XCTAssertNotNil([aItem submenu]);

    NSMenu *sub = [aItem submenu];
    // Should have: "a" (self-item), separator, "b"
    XCTAssertEqual([sub numberOfItems], 3);
    XCTAssertEqualObjects([[sub itemAtIndex:0] title], @"a");
    XCTAssertTrue([[sub itemAtIndex:1] isSeparatorItem]);
    XCTAssertEqualObjects([[sub itemAtIndex:2] title], @"b");

    // representedObject should point to the correct hosts
    XCTAssertEqual((Hosts*)[[sub itemAtIndex:0] representedObject], h1);
    XCTAssertEqual((Hosts*)[[sub itemAtIndex:2] representedObject], h2);
}

#pragma mark - firstLeafHosts

- (void)testFirstLeafHostsReturnsSelf {
    Hosts *h = [self hostsWithName:@"test"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h]];

    HostsMenuNode *child = root.children[root.childKeys[0]];
    XCTAssertEqual([child firstLeafHosts], h);
}

- (void)testFirstLeafHostsTraversesTree {
    Hosts *h1 = [self hostsWithName:@"xxx-yyy"];
    Hosts *h2 = [self hostsWithName:@"xxx-zzz"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h1, h2]];
    [menu compactNode:root];

    HostsMenuNode *xxx = root.children[root.childKeys[0]];
    XCTAssertEqual([xxx firstLeafHosts], h1); // first child in insertion order
}

#pragma mark - Indentation

- (void)testIndentationApplied {
    Hosts *h = [self hostsWithName:@"myhost"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h]];
    [menu compactNode:root];

    NSMenu *target = [[NSMenu alloc] init];
    [menu createMenuItemsFromNode:root intoMenu:target indentation:YES];

    XCTAssertEqual([[target itemAtIndex:0] indentationLevel], 1);
}

- (void)testNoIndentation {
    Hosts *h = [self hostsWithName:@"myhost"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h]];
    [menu compactNode:root];

    NSMenu *target = [[NSMenu alloc] init];
    [menu createMenuItemsFromNode:root intoMenu:target indentation:NO];

    XCTAssertEqual([[target itemAtIndex:0] indentationLevel], 0);
}

#pragma mark - Parent item representedObject

- (void)testParentItemRepresentedObject {
    // Parent submenu item should have firstLeafHosts as representedObject
    Hosts *h1 = [self hostsWithName:@"env-dev"];
    Hosts *h2 = [self hostsWithName:@"env-stg"];
    HostsMenu *menu = [[HostsMenu alloc] initWithTitle:@"test"];
    HostsMenuNode *root = [menu buildTrieFromHosts:@[h1, h2]];
    [menu compactNode:root];

    NSMenu *target = [[NSMenu alloc] init];
    [menu createMenuItemsFromNode:root intoMenu:target indentation:NO];

    NSMenuItem *parent = [target itemAtIndex:0];
    XCTAssertEqual((Hosts*)[parent representedObject], h1);
}

@end
