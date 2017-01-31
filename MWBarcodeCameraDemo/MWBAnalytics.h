//
//  MWBAnalytics.h
//  MWBAnalytics
//
//  Created by plaisio on 3/25/15.
//  Copyright (c) 2015 plaisio. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MWBAnalytics : NSObject


+(MWBAnalytics*)getInstance;
-(void)initializeAnalyticsWithUsername:(NSString *)apiUser apiKey:(NSString *)apiKey;
-(int)MWA_sendReport:(uint8_t*) encryptedResult resultType: (NSString *) resultType tag:(NSString*)tag;
@end
