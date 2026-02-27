#ifndef COMMANDS_H
#define COMMANDS_H

#include "supabase.h"

/* Fetch the next pending light command for this device.
 * Returns:
 *   1  if a command was found and *desired_state is set to 0/1
 *   0  if no pending command is available
 *  -1  on error
 */
int fetch_next_light_command(const supabase_config_t *cfg, int *desired_state, char *command_id_buf, int command_id_buf_len);

/* Mark a previously fetched light command as processed with given status ("executed" or "failed"). */
int mark_light_command_processed(const supabase_config_t *cfg, const char *command_id, const char *status);

#endif

