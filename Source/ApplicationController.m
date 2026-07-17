/***************************************************************************
 *   Copyright (C) 2009-2018 by Siim Raud   *
 *   siim@clockwise.ee   *
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

#import "ApplicationController.h"
#import "StructureConverter.h"
#import "Preferences.h"
#import "HostsMenu.h"
#import "PrivilegedActions.h"
#import "Host_Cassettes-Swift.h"
#import "LocalHostsController.h"
#import "RemoteHostsController.h"
#import "NotificationHelper.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <Sparkle/Sparkle.h>

@interface ApplicationController ()
{
	__weak NSWindow *_editorWindow;
}
@end

@interface ApplicationController(Private)
- (void)initStructure;
- (void)initEditorWindow;
- (void)activatePreviousFile:(NSNotification *)note;
- (void)activateNextFile:(NSNotification *)note;
- (void)notifyOfFileRestored:(NSNotification *)note;
- (void)notifyHostsChange:(Hosts*)hosts;
- (void)showApplicationInDock;
- (void)hideApplicationFromDock;
- (void)orderEditorWindowFront;
- (void)editorWindowWillClose:(NSNotification *)notification;
- (void)createHostsFileFromLocalURL:(NSURL*)url;
@end

@implementation ApplicationController


static ApplicationController *sharedInstance = nil;

static BOOL shouldConfigureSparkleUpdater(void)
{
	NSBundle *mainBundle = [NSBundle mainBundle];
	NSString *feedURL = [mainBundle objectForInfoDictionaryKey:@"SUFeedURL"];
	NSString *publicEDKey = [mainBundle objectForInfoDictionaryKey:@"SUPublicEDKey"];

	if (feedURL == nil || [feedURL length] == 0) {
		return NO;
	}

	if (publicEDKey == nil || [publicEDKey length] == 0) {
		return NO;
	}

	return ![publicEDKey isEqualToString:@"REPLACE_WITH_EDDSA_PUBLIC_KEY"];
}

+ (ApplicationController*)defaultInstance
{
	return sharedInstance;
}

- (id)init
{
    if (sharedInstance) {
        return sharedInstance;
    }
	if (self = [super init]) {
		shouldQuit = YES;

		BOOL isTesting = NSClassFromString(@"XCTestCase") != nil;
		if (!isTesting && shouldConfigureSparkleUpdater()) {
			_updaterController = [[SPUStandardUpdaterController alloc]
								  initWithStartingUpdater:YES
								  updaterDelegate:nil
								  userDriverDelegate:nil];
		}

		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(activatePreviousFile:) name:ActivatePreviousFileNotification object:nil];
		[nc addObserver:self selector:@selector(activateNextFile:) name:ActivateNextFileNotification object:nil];
        [nc addObserver:self selector:@selector(notifyOfFileRestored:) name:RestoredHostsFileNotification object:nil];

		sharedInstance = self;
		return self;
	}
    return sharedInstance;
}

- (SPUUpdater *)updater
{
	return _updaterController.updater;
}

-(IBAction)openPreferencesWindow:(id)sender
{
    [self showApplicationInDock];
	[PreferencesPresenter showPreferences];
}

- (IBAction)flushChrome:(id)sender
{
	NSURL *chromeURL = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:@"com.google.Chrome"];
	if (!chromeURL) return;
	NSURL *url = [NSURL URLWithString:@"chrome://net-internals/#sockets"];
	NSWorkspaceOpenConfiguration *config = [NSWorkspaceOpenConfiguration configuration];
	[[NSWorkspace sharedWorkspace] openURLs:@[url] withApplicationAtURL:chromeURL configuration:config completionHandler:nil];
}

- (IBAction)flushDNSCache:(id)sender
{
	LAContext *context = [[LAContext alloc] init];
	NSError *error = nil;

	if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
		[context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
				localizedReason:NSLocalizedString(@"Flush the DNS cache", @"Touch ID prompt for DNS cache flush")
						  reply:^(BOOL success, NSError *authError) {
			if (success) {
				NSTask *task = [[NSTask alloc] init];
				task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/dscacheutil"];
				task.arguments = @[@"-flushcache"];
				[task launchAndReturnError:nil];
			}
		}];
	} else {
		// No biometrics available, run directly
		NSTask *task = [[NSTask alloc] init];
		task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/dscacheutil"];
		task.arguments = @[@"-flushcache"];
		[task launchAndReturnError:nil];
	}
}

- (IBAction)displayAboutBox:(id)sender
{
	[AboutBoxPresenter show];
}

- (IBAction)reportBugs:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:IssueTrackerURL]];
}

- (IBAction)donate:(id)sender
{
	// Donate disabled for this fork
}

-(IBAction)quit:(id)sender
{
	[[NSApplication sharedApplication] terminate:self];
}

- (IBAction)openEditorWindow:(id)sender
{
	if (!editorWindowOpened) {
		if (_editorWindow) {
			editorWindowOpened = YES;
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(editorWindowWillClose:)
														 name:NSWindowWillCloseNotification
													   object:_editorWindow];
		} else {
			[self initEditorWindow];
		}
	}

	[self showApplicationInDock];
	[self orderEditorWindowFront];
}

- (IBAction)closeEditorWindow:(id)sender
{
	[self hideApplicationFromDock];
}

- (IBAction)addFromURL:(id)sender
{
	[URLSheetPresenter presentInWindow:nil];
}

- (IBAction)openHostsFile:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	UTType *hostsFileType = [UTType typeWithFilenameExtension:HostsFileExtension];
	if (hostsFileType != nil) {
		[panel setAllowedContentTypes:@[hostsFileType]];
	}
    NSModalResponse result = [panel runModal];
    if (result == NSModalResponseOK) {
		[self createHostsFileFromLocalURL:[[panel URLs] lastObject]];
	}
}

- (IBAction)updateAndSynchronize:(id)sender
{
	logDebug(@"Update & synchronize");
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:UpdateAndSynchronizeNotification object:nil];
}

- (BOOL)editorWindowOpened
{
	return editorWindowOpened;
}

#pragma mark - Application Delegate

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	(void)[GlobalShortcuts shared]; // Register global hotkeys

	checkForUpdatesMenuItem.target = _updaterController;
	checkForUpdatesMenuItem.action = @selector(checkForUpdates:);
	[checkForUpdatesMenuItem setEnabled:(_updaterController != nil)];

	[NSApp setServicesProvider:self];

	[self initStructure];

	[hostsController load];

	if (!openedAtLogin() && [Preferences showEditorWindow]) {
		[self openEditorWindow:nil];
	}
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	if (reopened() && [filename isEqual:@"#reopen#"]) {
		return NO;
	}
	
	logDebug(@"Opening file \"%@\"", filename);
	
	if ([[filename pathExtension] isEqual:HostsFileExtension]) {
		NSURL *url = [NSURL fileURLWithPath:filename];
		[self createHostsFileFromLocalURL:url];
		return YES;
	}
	
	return NO;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	shouldQuit = YES;
	if (!editorWindowOpened) {
		[self hideApplicationFromDock];
	}
	return NO;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	if (!shouldQuit) {
		[self hideApplicationFromDock];
	}
}

- (NSMenu *)applicationDockMenu:(NSApplication *)sender
{
	return [HostsMenu new];
}

#pragma mark -
#pragma mark CrashReportSenderDelegate

- (void) showMainApplicationWindow
{
	[[NSApp mainWindow] makeFirstResponder: nil];
	[[NSApp mainWindow] makeKeyAndOrderFront: nil];
}

#pragma mark -
#pragma mark Service Provider

-(void)createNewHostsFile:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
	logDebug(@"Creating new hosts file from dropped data");
    NSString * data = [pboard stringForType:NSPasteboardTypeString];
    
	NSURL *url = [NSURL URLWithString:data];
	if (url == nil) {
		[hostsController createNewHostsFileWithContents:data];
	}
	else {
		BOOL created = [hostsController createHostsFromURL:url forControllerClass:[RemoteHostsController class]];
		if (!created) {
			[hostsController createHostsFromURL:url forControllerClass:[LocalHostsController class]];
		}
	}
}

@end

@implementation ApplicationController(Private)

- (void)initStructure
{
	logDebug(@"Init structure");
	StructureConverter *structureConverter = [StructureConverter new];
	[structureConverter convertToCurrent];
}

- (void)initEditorWindow
{
	logDebug(@"Initializing editor window");
	_editorWindow = [EditorWindowPresenter createEditorWindow];
	editorWindowOpened = YES;
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(editorWindowWillClose:)
												 name:NSWindowWillCloseNotification
											   object:_editorWindow];
}

- (void)activatePreviousFile:(NSNotification *)note
{
	Hosts *hosts = [hostsController activatePrevious];
    [self notifyHostsChange:hosts];
}

- (void)activateNextFile:(NSNotification *)note
{
	Hosts *hosts = [hostsController activateNext];
    [self notifyHostsChange:hosts];
}

- (void)notifyOfFileRestored:(NSNotification *)note
{    
    [NotificationHelper notify:NSLocalizedString(@"Hosts File Restored", @"Notification title when hosts file is restored")
                       message:NSLocalizedString(@"External application has changed the hosts file.\nHost Cassettes restored previous state.", @"Notification message when hosts file is restored")];
}

- (void)notifyHostsChange:(Hosts*)hosts
{
    [NotificationHelper notify:NSLocalizedString(@"Hosts File Activated", @"Notification title when hosts file is activated") message:[hosts name]];
}

- (void)showApplicationInDock
{
	[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
	if (@available(macOS 14.0, *)) {
		[NSApp activate];
	} else {
		[NSApp activateIgnoringOtherApps:YES];
	}
}

- (void)hideApplicationFromDock
{
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	[Preferences setShowEditorWindow:NO];
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:NSWindowWillCloseNotification
												  object:_editorWindow];
	[_editorWindow orderOut:nil];
	editorWindowOpened = NO;
}

- (void)orderEditorWindowFront
{
	[_editorWindow makeKeyAndOrderFront:nil];
}

- (void)editorWindowWillClose:(NSNotification *)notification
{
	if (editorWindowOpened) {
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:NSWindowWillCloseNotification
													  object:[notification object]];
		[self hideApplicationFromDock];
	}
}

- (void)createHostsFileFromLocalURL:(NSURL*)url
{
	if ([hostsController hostsFileWithLocalURLExists:url]) {
		Hosts *hosts = [hostsController hostsFileWithLocalURL:url];
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc postNotificationName:HostsFileShouldBeSelectedNotification object:hosts];
	}
	else {
		[hostsController createHostsFromLocalURL:url forControllerClass:[LocalHostsController class]];
	}
}

@end
