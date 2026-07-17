/***************************************************************************
 *   Copyright (C) 2009-2010 by Clockwise   *
 *   copyright@clockwise.ee   *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
 ***************************************************************************/

#import "HostsMenu.h"
#import "HostsMainController.h"
#import "ApplicationController.h"
#import "RemoteHostsController.h"
#import "Pair.h"

#pragma mark - HostsMenuNode (Trie node for submenu grouping)

@interface HostsMenuNode : NSObject
@property (nonatomic, strong) NSString *label;
@property (nonatomic, strong) Hosts *hosts; // non-nil only for leaf nodes
@property (nonatomic, strong) NSMutableArray<NSString*> *childKeys; // insertion-ordered keys
@property (nonatomic, strong) NSMutableDictionary<NSString*, HostsMenuNode*> *children;
- (Hosts*)firstLeafHosts;
@end

@implementation HostsMenuNode

- (instancetype)init {
	self = [super init];
	if (self) {
		_childKeys = [NSMutableArray array];
		_children = [NSMutableDictionary dictionary];
	}
	return self;
}

- (void)addChild:(HostsMenuNode*)child forKey:(NSString*)key {
	if (!_children[key]) {
		[_childKeys addObject:key];
	}
	_children[key] = child;
}

- (Hosts*)firstLeafHosts {
	if (_hosts) return _hosts;
	for (NSString *key in _childKeys) {
		Hosts *h = [_children[key] firstLeafHosts];
		if (h) return h;
	}
	return nil;
}

@end

#pragma mark -

@interface HostsMenu (Private)
- (void)createItems;
- (void)createItemsFromHosts:(NSArray*)hostsArray indentation:(BOOL)indentation;
- (void)createItemsFromHosts:(NSArray*)hostsArray withTitle:(NSString*)title;
- (void)createExtraItems;
- (BOOL)haveItemsInOneGroup:(NSArray*)goupPairs;
- (HostsMenuNode*)buildTrieFromHosts:(NSArray*)hostsArray;
- (void)compactNode:(HostsMenuNode*)node;
- (void)createMenuItemsFromNode:(HostsMenuNode*)node intoMenu:(NSMenu*)menu indentation:(BOOL)indentation;
@end

@implementation HostsMenu

- (id)init
{
	self = [super init];
	
	[self createItems];
	
	return self;
}

- (id)initWithExtras
{
	self = [self init];
	[self createExtraItems];
	
	return self;
}

@end

@implementation HostsMenu (Private)

-(IBAction)activateHostsFile:(id)sender
{
    Hosts *hosts = (Hosts*)[sender representedObject];
    if (![hosts active]) {
        [[HostsMainController defaultInstance] activateHostsFile:hosts];
    }
}

- (void)createItems
{
	NSArray *pairs = [[HostsMainController defaultInstance] allHostsFilesGrouped];
	
	if ([self haveItemsInOneGroup:pairs]) {
		for (int i=0; i<[pairs count]; i++) {
			[self createItemsFromHosts:(NSArray*)[[pairs objectAtIndex:i] right] indentation:NO];
		}
	}
	else {
		for (int i=0; i<[pairs count]; i++) {
			Pair *pair = [pairs objectAtIndex:i];
			[self createItemsFromHosts:(NSArray*)[pair right] withTitle:(NSString*)[pair left]];
		}
	}
}

- (void)createItemsFromHosts:(NSArray*)hostsArray indentation:(BOOL)indentation
{
	HostsMenuNode *root = [self buildTrieFromHosts:hostsArray];
	[self compactNode:root];
	[self createMenuItemsFromNode:root intoMenu:self indentation:indentation];
}
 
- (void)createItemsFromHosts:(NSArray*)hostsArray withTitle:(NSString*)title
{
	if ([hostsArray count] > 0) {
		NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:NULL keyEquivalent:@""];
		[self addItem:item];

	}
	[self createItemsFromHosts:hostsArray indentation:YES];
}

- (void)createExtraItems
{	
	[self addItem:[NSMenuItem separatorItem]];
	
	ApplicationController *controller = [ApplicationController defaultInstance];
	NSMenuItem *item;
	
	if ([controller editorWindowOpened]) {
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Close Editor Window", @"Menu item to close editor window") action:NULL keyEquivalent:@""];
		[item setAction:@selector(closeEditorWindow:)];
	}
	else {
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Show Editor Window", @"Menu item to show editor window") action:NULL keyEquivalent:@""];
		[item setAction:@selector(openEditorWindow:)];
	}
	[item setTarget:controller];
	[self addItem:item];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Preferences...", @"Menu item to open preferences") action:NULL keyEquivalent:@""];
	[item setAction:@selector(openPreferencesWindow:)];
	[item setTarget:controller];
	[self addItem:item];
	
	// Apply Hosts Changes submenu
	NSMenu *flushSubmenu = [[NSMenu alloc] init];
	
	NSMenuItem *dnsItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Flush DNS Cache", @"Menu item to flush DNS cache") action:NULL keyEquivalent:@""];
	[dnsItem setAction:@selector(flushDNSCache:)];
	[dnsItem setTarget:controller];
	[flushSubmenu addItem:dnsItem];
	
	
	NSMenuItem *chromeItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Chrome", @"Menu item to flush Chrome") action:NULL keyEquivalent:@""];
	if ([[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:@"com.google.Chrome"]) {
		[chromeItem setAction:@selector(flushChrome:)];
		[chromeItem setTarget:controller];
	}
	[chromeItem setToolTip:NSLocalizedString(@"Flush socket pools", @"Tooltip for Chrome flush menu item")];
	[flushSubmenu addItem:chromeItem];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Apply Hosts Changes", @"Menu item to apply hosts changes to browsers") action:NULL keyEquivalent:@""];
	[item setSubmenu:flushSubmenu];
	[self addItem:item];
	
	if ([[HostsMainController defaultInstance] hostsFilesExistForControllerClass:[RemoteHostsController class]]) {
		[self addItem:[NSMenuItem separatorItem]];
	
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Update Remote Files", @"Menu item to update remote hosts files") action:NULL keyEquivalent:@""];
		[item setAction:@selector(updateAndSynchronize:)];
		[item setTarget:controller];
		[self addItem:item];
	}
	
	[self addItem:[NSMenuItem separatorItem]];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Quit Host Cassettes", @"Menu item to quit application") action:NULL keyEquivalent:@""];
	[item setAction:@selector(quit:)];
	[item setTarget:controller];
	[self addItem:item];
}

- (BOOL)haveItemsInOneGroup:(NSArray*)goupPairs
{
	BOOL haveInGroup = NO;
	
	for (int i=0; i<[goupPairs count]; i++) {
		NSArray *items = (NSArray*)[[goupPairs objectAtIndex:i] right];
		if ([items count] > 0) {
			if (haveInGroup) {
				return NO;
			}
			else {
				haveInGroup = YES;
			}
		}
	}
	return haveInGroup;
}

#pragma mark - Trie-based submenu grouping

- (HostsMenuNode*)buildTrieFromHosts:(NSArray*)hostsArray
{
	HostsMenuNode *root = [[HostsMenuNode alloc] init];

	for (Hosts *hosts in hostsArray) {
		NSString *name = [hosts name];
		NSArray<NSString*> *components = [name componentsSeparatedByString:@"-"];
		HostsMenuNode *current = root;

		for (NSUInteger i = 0; i < [components count]; i++) {
			NSString *key = [components objectAtIndex:i];
			HostsMenuNode *child = current.children[key];
			if (!child) {
				child = [[HostsMenuNode alloc] init];
				child.label = key;
				[current addChild:child forKey:key];
			}
			current = child;
		}
		current.hosts = hosts;
	}

	return root;
}

- (void)compactNode:(HostsMenuNode*)node
{
	// Recurse into children first
	for (NSString *key in [node.childKeys copy]) {
		[self compactNode:node.children[key]];
	}

	// If this node has exactly one child and is not itself a leaf, merge with child
	// Skip root node (label == nil) since it's a virtual container
	while ([node.childKeys count] == 1 && node.hosts == nil && node.label != nil) {
		NSString *childKey = [node.childKeys firstObject];
		HostsMenuNode *child = node.children[childKey];
		if (node.label) {
			node.label = [NSString stringWithFormat:@"%@-%@", node.label, child.label];
		} else {
			node.label = child.label;
		}
		node.hosts = child.hosts;
		node.childKeys = child.childKeys;
		node.children = child.children;
	}
}

- (void)createMenuItemsFromNode:(HostsMenuNode*)node intoMenu:(NSMenu*)menu indentation:(BOOL)indentation
{
	for (NSString *key in node.childKeys) {
		HostsMenuNode *child = node.children[key];
		BOOL isLeaf = ([child.childKeys count] == 0);

		if (isLeaf) {
			// Leaf node: create a regular menu item
			Hosts *hosts = child.hosts;
			NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:child.label action:NULL keyEquivalent:@""];
			[item setRepresentedObject:hosts];
			if (indentation) {
				[item setIndentationLevel:1];
			}
			if (hosts && [hosts selectable]) {
				[item setAction:@selector(activateHostsFile:)];
				[item setTarget:self];
			}
			if (hosts && [hosts active]) {
				[item setState:NSControlStateValueOn];
			}
			[menu addItem:item];
		} else {
			// Branch node: create submenu
			NSMenu *submenu = [[NSMenu alloc] initWithTitle:child.label];
			NSMenuItem *parentItem = [[NSMenuItem alloc] initWithTitle:child.label action:NULL keyEquivalent:@""];

			// If this branch node is also a leaf (e.g. "a" exists alongside "a-b"),
			// add the leaf entry at the top of the submenu
			if (child.hosts) {
				Hosts *hosts = child.hosts;
				NSMenuItem *selfItem = [[NSMenuItem alloc] initWithTitle:child.label action:NULL keyEquivalent:@""];
				[selfItem setRepresentedObject:hosts];
				if (hosts && [hosts selectable]) {
					[selfItem setAction:@selector(activateHostsFile:)];
					[selfItem setTarget:self];
				}
				if (hosts && [hosts active]) {
					[selfItem setState:NSControlStateValueOn];
				}
				[submenu addItem:selfItem];
				[submenu addItem:[NSMenuItem separatorItem]];
			}

			// Recursively add children into the submenu
			[self createMenuItemsFromNode:child intoMenu:submenu indentation:NO];

			// Check if any descendant is active, and mark parent accordingly
			Hosts *firstLeaf = [child firstLeafHosts];
			if (firstLeaf) {
				[parentItem setRepresentedObject:firstLeaf];
				[parentItem setAction:@selector(activateHostsFile:)];
				[parentItem setTarget:self];
			}

			[parentItem setSubmenu:submenu];
			if (indentation) {
				[parentItem setIndentationLevel:1];
			}
			[menu addItem:parentItem];
		}
	}
}

 @end