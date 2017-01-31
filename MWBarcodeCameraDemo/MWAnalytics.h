//
//  analytics.h
//  BarcodeScanner
//
//  Created by Vladimir Zivkovic on 2/18/16.
//
//

#ifndef analytics_h
#define analytics_h



#if (PLATFORM == PLATFORM_IPHONE) || (PLATFORM == PLATFORM_ANDROID)

#define ENABLE_ANALYTICS

#else

#undef ENABLE_ANALYTICS

#endif

void MWA_initialize(char * username, char *apiKey);
int MWA_sendReport(char * encryptedResult, char *resultType, char*tag);


#endif /* analytics_h */
