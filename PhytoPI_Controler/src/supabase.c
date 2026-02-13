#include "../lib/supabase.h"
#include <curl/curl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <json-c/json.h>

static CURL *curl_handle = NULL;

/*
 * Initialize Supabase HTTP client
 * Returns 0 on success, -1 on failure
 */
int supabase_init(supabase_config_t *config)
{
    if (!config || !config->api_url || !config->api_key)
    {
        fprintf(stderr, "Supabase config is invalid\n");
        return -1;
    }

    curl_global_init(CURL_GLOBAL_DEFAULT);
    curl_handle = curl_easy_init();

    if (!curl_handle)
    {
        fprintf(stderr, "Failed to initialize curl\n");
        return -1;
    }

    return 0;
}

/*
 * Cleanup Supabase HTTP client
 */
int supabase_cleanup(void)
{
    if (curl_handle)
    {
        curl_easy_cleanup(curl_handle);
        curl_handle = NULL;
    }
    curl_global_cleanup();
    return 0;
}

/*
 * Send a batch of readings to Supabase
 * Returns 0 on success, -1 on failure
 */
int supabase_send_batch(supabase_config_t *config, supabase_reading_t *readings, int count)
{
    if (!config || !readings || count <= 0)
    {
        fprintf(stderr, "Invalid parameters for batch send\n");
        return -1;
    }

    if (!curl_handle)
    {
        fprintf(stderr, "Supabase not initialized\n");
        return -1;
    }

    // Build JSON array of readings
    json_object *json_array = json_object_new_array();
    
    for (int i = 0; i < count; i++)
    {
        json_object *reading = json_object_new_object();
        
        // Add sensor_id
        json_object_object_add(reading, "sensor_id", 
                              json_object_new_string(readings[i].sensor_id));
        
        // Add value
        json_object_object_add(reading, "value", 
                              json_object_new_double(readings[i].value));
        
        // Add timestamp (convert to ISO 8601 format)
        char timestamp_str[64];
        time_t ts = (time_t)readings[i].timestamp;
        struct tm *tm_info = gmtime(&ts);
        strftime(timestamp_str, sizeof(timestamp_str), "%Y-%m-%dT%H:%M:%SZ", tm_info);
        json_object_object_add(reading, "ts", 
                              json_object_new_string(timestamp_str));
        
        // Add metadata if provided
        if (readings[i].metadata)
        {
            json_object *metadata_obj = json_tokener_parse(readings[i].metadata);
            if (metadata_obj)
            {
                json_object_object_add(reading, "metadata", metadata_obj);
            }
        }
        
        json_object_array_add(json_array, reading);
    }

    const char *json_string = json_object_to_json_string(json_array);
    
    // Build URL
    char url[512];
    snprintf(url, sizeof(url), "%s/rest/v1/readings", config->api_url);

    // Build headers
    struct curl_slist *headers = NULL;
    char apikey_header[256];
    char auth_header[256];
    snprintf(apikey_header, sizeof(apikey_header), "apikey: %s", config->api_key);
    snprintf(auth_header, sizeof(auth_header), "Authorization: Bearer %s", config->api_key);
    headers = curl_slist_append(headers, apikey_header);
    headers = curl_slist_append(headers, auth_header);
    headers = curl_slist_append(headers, "Content-Type: application/json");
    headers = curl_slist_append(headers, "Prefer: return=minimal");

    // Configure curl
    curl_easy_setopt(curl_handle, CURLOPT_URL, url);
    curl_easy_setopt(curl_handle, CURLOPT_POSTFIELDS, json_string);
    curl_easy_setopt(curl_handle, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl_handle, CURLOPT_POST, 1L);

    // Perform request
    CURLcode res = curl_easy_perform(curl_handle);
    
    long response_code;
    curl_easy_getinfo(curl_handle, CURLINFO_RESPONSE_CODE, &response_code);

    // Cleanup
    curl_slist_free_all(headers);
    json_object_put(json_array);

    if (res != CURLE_OK)
    {
        fprintf(stderr, "curl_easy_perform() failed: %s\n", curl_easy_strerror(res));
        return -1;
    }

    if (response_code >= 200 && response_code < 300)
    {
        printf("Successfully sent %d readings to Supabase (HTTP %ld)\n", count, response_code);
        return 0;
    }
    else
    {
        fprintf(stderr, "Supabase API returned error code: %ld\n", response_code);
        return -1;
    }
}

