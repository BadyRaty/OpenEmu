/*
 Copyright (c) 2012, OpenEmu Team
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "OEImportItem.h"
#import "OESystemPlugin.h"
#import "NSURL+OELibraryAdditions.h"
#import "OEROMImporter.h"
#import <MagicKit/MagicKit.h>

@implementation OEImportItem
@synthesize URL=_URL;

+ (OEImportItem *)itemWithURL:(NSURL *)url completionHandler:(OEImportItemCompletionBlock)handler
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [url path];

    BOOL isDirectory = NO;
    if(![fileManager fileExistsAtPath:path isDirectory:&isDirectory])
        return nil;

    // Ignore hidden or package files
    NSDictionary *resourceValues = [url resourceValuesForKeys:@[ NSURLIsPackageKey, NSURLIsHiddenKey ] error:nil];
    if([[resourceValues objectForKey:NSURLIsHiddenKey] boolValue] || [[resourceValues objectForKey:NSURLIsPackageKey] boolValue])
    {
        // DLog(@"%@ is a hidden file or a package directory, skipping", path);
        return nil;
    }

    NSString *pathExtension = [[url pathExtension] lowercaseString];

    // Copy .cg to Filters folder
    if([pathExtension isEqualToString:@"cg"])
    {
        NSString *cgFilename = [path lastPathComponent];
        NSString *filtersPath = [NSString pathWithComponents:@[
                                    [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject],
                                    @"OpenEmu", @"Filters"]];
        NSString *destFilePath = [filtersPath stringByAppendingPathComponent:cgFilename];

        [fileManager createDirectoryAtPath:filtersPath withIntermediateDirectories:YES attributes:nil error:nil];
        [fileManager copyItemAtPath:path toPath:destFilePath error:nil];
        
        return nil;
    }
    
    // Ignore text files that are .md
    if([pathExtension isEqualToString:@"md"] && [[[GEMagicKit magicForFileAtURL:url] uniformTypeHierarchy] containsObject:(id)kUTTypeText])
    {
        // DLog(@"%@ is a text file, skipping", path);
        return nil;
    }

    // Copy known BIOS / System Files to BIOS folder
    for(NSDictionary *validFile in [OESystemPlugin requiredFiles])
    {
        NSString *biosSystemFileName = [validFile objectForKey:@"Name"];
        NSString *biosFilename = [path lastPathComponent];

        if([biosFilename caseInsensitiveCompare:biosSystemFileName] == NSOrderedSame)
        {
            NSString *biosPath = [NSString pathWithComponents:@[
                [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject],
                @"OpenEmu", @"BIOS" ]];
            [fileManager createDirectoryAtPath:biosPath withIntermediateDirectories:YES attributes:nil error:nil];

            NSString *destFilePath = [biosPath stringByAppendingPathComponent:biosFilename];
            [fileManager copyItemAtPath:path toPath:destFilePath error:nil];

            return nil;
        }
    }

    // Ignore unsupported file extensions
    NSMutableSet *validExtensions = [NSMutableSet setWithArray:[OESystemPlugin supportedTypeExtensions]];

    // The Archived Game document type lists all supported archive extensions, e.g. zip
    NSDictionary *bundleInfo      = [[NSBundle mainBundle] infoDictionary];
    NSArray      *docTypes        = [bundleInfo objectForKey:@"CFBundleDocumentTypes"];
    for(NSDictionary *docType in docTypes)
    {
        if([[docType objectForKey:@"CFBundleTypeName"] isEqualToString:@"Archived Game"])
        {
            [validExtensions addObjectsFromArray:[docType objectForKey:@"CFBundleTypeExtensions"]];
            break;
        }
    }

    if(!isDirectory)
    {
        if([pathExtension length] > 0 && ![validExtensions containsObject:pathExtension])
        {
            // DLog(@"%@ is not a supported file extension, skipping", extension);
            return nil;
        }
    }

    OEImportItem *item = [[OEImportItem alloc] init];

    [item setURL:url];
    [item setSourceURL:url];
    [item setCompletionHandler:handler];
    [item setImportState:OEImportItemStatusIdle];
    [item setImportInfo:[NSMutableDictionary dictionaryWithCapacity:5]];

    return item;
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [self init];
    if (self)
    {        
        [self setURL:[decoder decodeObjectForKey:@"URL"]];
        [self setSourceURL:[decoder decodeObjectForKey:@"sourceURL"]];
        [self setImportState:OEImportItemStatusIdle];
        [self setImportInfo:[decoder decodeObjectForKey:@"importInfo"]];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:[self URL] forKey:@"URL"];
    [encoder encodeObject:[self sourceURL] forKey:@"sourceURL"];
    [encoder encodeObject:[self importInfo] forKey:@"importInfo"];
}

- (void)setURL:(NSURL *)URL
{
    if([self archive])
        [[self archive] setURL:URL];
    else
        _URL = URL;
}

- (NSURL*)URL
{
    if([self archive])
        return [[self archive] URL];
    return _URL;
}
@end
