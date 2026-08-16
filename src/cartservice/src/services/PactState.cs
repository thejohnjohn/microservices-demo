// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using cartservice.cartstore;

namespace cartservice.services
{
    public static class PactState
    {
        // Provider state setup endpoint used by the Pact verifier. When an
        // interaction requires a provider state, the verifier POSTs here so the
        // provider can prepare its data before the interaction is replayed.
        public static async Task Setup(HttpContext context, ICartStore cartStore)
        {
            using var reader = new StreamReader(context.Request.Body);
            var body = await reader.ReadToEndAsync();

            using var doc = JsonDocument.Parse(string.IsNullOrEmpty(body) ? "{}" : body);
            var state = doc.RootElement.TryGetProperty("state", out var stateElement)
                ? stateElement.GetString()
                : null;

            if (state != null && state.Contains("user 'abc123' has an existing cart"))
            {
                await cartStore.AddItemAsync("abc123", "OLJCESPC7Z", 2);
            }

            context.Response.StatusCode = StatusCodes.Status200OK;
        }
    }
}
