/***************************************************************************
 *   Copyright (C) 2009-2012 by Clockwise   *
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

#import "FileUtil.h"
#import "Preferences.h"

static NSString *dataDirectory = nil;

@implementation FileUtil

+ (void)migrateFromGasMaskIfNeeded
{
	NSArray *array = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	NSString *libraryDir = [array objectAtIndex:0];
	NSString *oldDir = [libraryDir stringByAppendingString:@"/Gas Mask"];
	NSString *newDir = [libraryDir stringByAppendingString:@"/Host Cassettes"];
	NSFileManager *fm = [NSFileManager defaultManager];

	BOOL oldExists = [fm fileExistsAtPath:oldDir];
	BOOL newExists = [fm fileExistsAtPath:newDir];

	if (!oldExists) {
		return;
	}

	if (!newExists) {
		// Host Cassettes ディレクトリが存在しない場合は Gas Mask ディレクトリを移動
		logDebug(@"Migrating data from ~/Library/Gas Mask to ~/Library/Host Cassettes");
		NSError *error = nil;
		[fm moveItemAtPath:oldDir toPath:newDir error:&error];
		if (error) {
			logDebug(@"Migration failed: %@", [error localizedDescription]);
			return;
		}
	} else {
		// 両方のディレクトリが存在する場合は Gas Mask から未移行ファイルをコピー
		logDebug(@"Importing missing files from ~/Library/Gas Mask into ~/Library/Host Cassettes");
		NSArray *subDirs = @[@"Local", @"Remote", @"Combined"];
		for (NSString *subDir in subDirs) {
			NSString *srcSubDir = [oldDir stringByAppendingPathComponent:subDir];
			NSString *dstSubDir = [newDir stringByAppendingPathComponent:subDir];
			if (![fm fileExistsAtPath:srcSubDir]) {
				continue;
			}
			[fm createDirectoryAtPath:dstSubDir withIntermediateDirectories:YES attributes:nil error:nil];
			NSArray *files = [fm contentsOfDirectoryAtPath:srcSubDir error:nil];
			for (NSString *file in files) {
				NSString *src = [srcSubDir stringByAppendingPathComponent:file];
				NSString *dst = [dstSubDir stringByAppendingPathComponent:file];
				if (![fm fileExistsAtPath:dst]) {
					NSError *copyError = nil;
					[fm copyItemAtPath:src toPath:dst error:&copyError];
					if (copyError) {
						logDebug(@"Failed to import %@: %@", file, [copyError localizedDescription]);
					}
				}
			}
		}
	}

	// activeHostsFile 設定が Gas Mask のパスを指している場合は Host Cassettes のパスに更新
	NSString *oldPathPrefix = [oldDir stringByAppendingString:@"/"];
	NSString *newPathPrefix = [newDir stringByAppendingString:@"/"];
	NSString *activeFile = [Preferences activeHostsFile];
	if ([activeFile hasPrefix:oldPathPrefix]) {
		NSString *relativePath = [activeFile substringFromIndex:[oldPathPrefix length]];
		NSString *updatedPath = [newPathPrefix stringByAppendingString:relativePath];
		[Preferences setActiveHostsFile:updatedPath];
		logDebug(@"Updated activeHostsFile preference path: %@", updatedPath);
	}
}

+ (NSString*)dataDirectory
{
	if (dataDirectory == nil) {
		[FileUtil migrateFromGasMaskIfNeeded];
		NSArray *array = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
		dataDirectory = [[array objectAtIndex:0] stringByAppendingString:@"/Host Cassettes/"];
	}
	return dataDirectory;
}

+ (NSString*)localHostFilesDirectory
{
	return [[FileUtil dataDirectory] stringByAppendingString:@"Local/"];
}

+ (NSString*)remoteHostFilesDirectory
{
	return [[FileUtil dataDirectory] stringByAppendingString:@"Remote/"];
}

+ (NSString*) combinedHostsFilesDirectory
{
    return [[FileUtil dataDirectory] stringByAppendingString:@"Combined/"];
}

+ (BOOL)moveToTrash:(NSString *)path
{
	NSURL *fileURL = [NSURL fileURLWithPath:path];
	NSError *error = nil;
	BOOL success = [[NSFileManager defaultManager] trashItemAtURL:fileURL
	                                          resultingItemURL:nil
	                                                       error:&error];
	if (!success) {
		if ([[error domain] isEqualToString:NSCocoaErrorDomain] && [error code] == NSFileNoSuchFileError) {
			logDebug(@"File not found: \"%@\"", path);
		} else {
			logDebug(@"Failed to move file to trash: %@", [error localizedDescription]);
		}
	}
	return success;
}

@end
