// Copyright 2015-2019 Espressif Systems (Shanghai) PTE LTD
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <stdarg.h>
#include "esp_flash.h"

#include "esp32/rom/ets_sys.h"
#include "esp32/rom/cache.h"
#include "esp_attr.h"



static IRAM_ATTR esp_err_t start(void *arg)
{
    Cache_Read_Disable(0);
    Cache_Read_Disable(1);
    return ESP_OK;
}

static IRAM_ATTR esp_err_t end(void *arg)
{
    Cache_Flush(0);
    Cache_Flush(1);
    Cache_Read_Enable(0);
    Cache_Read_Enable(1);
    return ESP_OK;
}

static IRAM_ATTR esp_err_t delay_us(void *arg, unsigned us)
{
    ets_delay_us(us);
    return ESP_OK;
}

const DRAM_ATTR esp_flash_os_functions_t esp_flash_noos_functions = {
    .start = start,
    .end = end,
    .delay_us = delay_us,
    .region_protected = NULL,
};

esp_err_t IRAM_ATTR esp_flash_app_disable_os_functions(esp_flash_t* chip)
{
    chip->os_func = &esp_flash_noos_functions;
    return ESP_OK;
}
