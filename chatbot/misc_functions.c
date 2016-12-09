//
//  misc_functions.c
//  chatbot
//
//  Created by Ashish Ahuja on 28/5/16.
//  Copyright © 2016 Ashish Ahuja (Fortunate-MAN). All rights reserved.
//

#include <ctype.h>

#include <curl/curl.h>
#include "Client.h"
#include "ChatBot.h"

void lowercase (char *str)
{
    while (*str)
    {
        *str = tolower(*str);
        str++;
    }

    return;
}

void removeSubstring(char *s,const char *toremove)
{
  while( s=strstr(s,toremove) )
    memmove(s,s+strlen(toremove),1+strlen(s+strlen(toremove)));
}

void removeSpaces(char* source)
{
    if (source == NULL)
        return;
    char* i = source;
    char* j = source;
    while(*j != 0)
    {
        *i = *j++;
        if(*i != ' ')
            i++;
    }
    *i = 0;

    return;
}

//Copied from http://stackoverflow.com/a/784455/5735775
void reverseString(char *str)
{
    /* skip null */
    if (str == 0)
    {
    	return;
    }

    /* skip empty string */
    if (*str == 0)
    {
    	return;
    }

    /* get range */
    char *start = str;
    char *end = start + strlen(str) - 1; /* -1 for \0 */
    char temp;

    /* reverse */
    while (end > start)
    {
    	/* swap */
    	temp = *start;
    	*start = *end;
    	*end = temp;

    	/* move */
    	++start;
    	--end;
    }
}

int isTagProgrammingRelated (char *tag)
{
    char *progTags[] = {
        ".net",
        "accessibility-api",
        "actionscript",
        "actionscript-3",
        "ajax",
        "alljoyn",
        "applescript",
        "android-ndk",
        "android-sdk",
        "android-sdk-2.1",
        "android-sdk-2.2",
        "android-sdk-2.3",
        "anrdoid-sdk-tools",
        "android-studio",
        "angularjs",
        "asp.net",
        "asp.net5",
        "asp.net-mvc",
        "asp.net-mvc-3",
        "asp.net-mvc-4",
        "asp.net-mvc-5",
        "asp.net-mvc6",
        "awk",
        "bash",
        "c",
        "c#",
        "c++",
        "c++11",
        "cakephp",
        "cakephp-1.0",
        "cakephp-1.3",
        "cakephp-2.0",
        "cakephp-2.1",
        "cakephp-2.3",
        "cakephp-3.0",
        "clisp",
        "clojure",
        "cocoa",
        "cocoa-touch",
        "cocos2d",
        "cocos2d-iphone",
        "cocos2d-x",
        "codeigniter",
        "common-lisp",
        "cordova",
        "core-text",
        "css",
        "data-structures",
        "delphi",
        "django",
        "dom",
        "elisp",
        "excel-vba",
        "expect",
        "git",
        "grails",
        "hadoop",
        "haskell",
        "html",
        "html5",
        "jasper-reports",
        "java",
        "java-ee",
        "javascript",
        "jpa",
        "jsf",
        "json",
        "jsp",
        "jquery",
        "jquery-ui",
        "laravel",
        "lisp",
        "magento",
        "matlab",
        "maven",
        "mercurial",
        "mongodb",
        "msbuild",
        "mybatis",
        "mysql",
        "netbeans",
        "node.js",
        "numpy",
        "objective-c",
        "oop",
        "opencv",
        "opengl",
        "oracle",
        "pandas",
        "perl",
        "powershell",
        "php",
        "prolog",
        "python",
        "python-2.7",
        "python-2.x",
        "python-3.x",
        "qt",
        "r",
        "racket",
        "regex",
        "ruby",
        "ruby-on-rails",
        "ruby-on-rails-3",
        "ruby-on-rails-4",
        "sapui",
        "sapui5",
        "scala",
        "scheme",
        "sed",
        "selenium",
        "sh",
        "shell",
        "sockets",
        "spring-mybatis",
        "spring-mvc",
        "sql",
        "sql-server",
        "sql-server-2008",
        "sqlite",
        "swift",
        "symfony1",
        "symfony2",
        "symfony3",
        "tcl",
        "tsql",
        "vb.net",
        "vb6",
        "vba",
        "vbscript",
        "verilog",
        "visual-studio",
        "visual-studio-2010",
        "vscode",
        "winapi",
        "wcf",
        "xaml",
        "xcode",
        "xml",
        "xslt"
    };

    for (int i = 0; i < 139; i ++)
    {
        if (strcasestr (tag, progTags [i]) == tag)
        {
            return 1;
        }
    }

    return 0;
}

int postHasTags (ChatBot *bot, Post *post, char *tag)
{
    char **tags = getTagsByID (bot, post->postID);

    for (int i = 0; i < 5; i ++)
    {
        if (strcmp (tags [i], tag) == 0)
        {
            return 1;
        }
    }

    return 0;
}


void removeChar (char *str, char c);
//unsigned isTagInFilter (ChatBot *bot, char *tag);

unsigned isTagInFilter (ChatBot *bot, char *tag)
{
    Filter **filters = bot->filters;

    for (int i = 0; i < bot->filterCount; i ++)
    {
        if (strcmp (filters [i]->filter, tag) == 0)
        {
            return 1;
        }
    }

    return 0;
}

void removeChar (char *str, char c) {
    char *pr = str;
    char *pw = str;
    while (*pr) {
        *pw = *pr++;
        pw += (*pw != c);
    }
    *pw = '\0';
}

unsigned getCapsInString (char *str)
{
    unsigned len = strlen (str);
    unsigned totalCaps = 0;
    for (int i = 0; i < len; i ++)
    {
        if (str [i] <= 'Z' && str [i] >= 'A')
        {
            totalCaps ++;
        }
    }

    return totalCaps;
}

unsigned isStringContainingNumbers2 (char *str)
{
    unsigned len = strlen (str);
    unsigned i;

    for (i = 0; i < len; i ++)
    {
        if (str [i] < 0 || str [i] > 9)
        {
            return 0;
        }
    }

    return 1;
}

unsigned isFileEmpty (FILE *file)
{
    fseek(file, 0, SEEK_END);
    unsigned long len = (unsigned long)ftell(file);
    if (len > 0)
        return 0;
    else
        return 1;
}

void removeAllChars (char *str)
{
     unsigned i = 0, j = 0;
     char *temp = malloc (sizeof (char) * 100);
while (i != strlen (str))
{
    if ((str[i] >= 48) && (str[i] <= 57))
    {
        temp[j] = str[i];
        i++;
        j++;
    }
    else
    {
        i++;
    }
}
str = temp;
}

char *getCurrentTime ()
{
    time_t t;
    time (&t);
    return asctime (localtime (&t));
}

char *readLine (FILE *file, int lineNum)
{
    char *line = malloc (sizeof (char) * 256);
    unsigned i;
    for (i = 0; fgets(line, sizeof (line), file) != NULL; i ++)
    {
        if (i == lineNum)
        {
            break;
        }
    }
    return line;
}

long long getCurrentTimeInSeconds ()
{
    system ("date +%s > time.txt");
    FILE *file = fopen ("time.txt", "r");
    char *line = readLine (file, 1);
    fclose (file);
    long long time = strtoll (line, NULL, 10);
    free (line);
    return time;
}

char *getCurrentUTCTime ()
{
    struct tm *local;
    time_t t;

    t = time(NULL);
    local = gmtime(&t);
    return asctime (local);
}

char *concat (const char *s1, const char *s2)
{
    char *result = malloc (strlen(s1) + strlen(s2) + 1);
    strcpy (result, s1);
    strcat (result, s2);
    return result;
}

char *executeCommand (char *command)
{
    FILE *file;
    char *output = malloc (2048);

    //Open a pipe for executing the command
    file = popen (command, "r");

    fgets (output, 2048, file);

    if (pclose (file) != 0)
    {
        fputs ("Failed to close command pipe!", stderr);
        return NULL;
    }
    return output;
}

//http://stackoverflow.com/a/1515208/5735775
void stripNewlines(char *s) {
    char *p2 = s;
    while(*s != '\0') {
        if(*s != '\t' && *s != '\n') {
            *p2++ = *s++;
        } else {
            ++s;
        }
    }
    *p2 = '\0';
}