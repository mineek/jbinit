//
//  libarchive.h
//  
//
//  Created by Serena on 22/11/2022
//
	

#ifndef libarchive_h
#define libarchive_h

@import Foundation;
#include "archive_entry.h"
#include "archive.h"

void extractPath(NSString *path, NSString *destination, NSError **error);

#endif /* libarchive_h */
