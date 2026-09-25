# Policy tab: AI
#
# Brave's own AI: Leo and the on-device models behind features such as history
# search. Chromium's Gemini-era AI policies are not listed: Brave builds those
# features out, so the policies change nothing.
@{
    Category = 'aiGenAi'
    Policies = @(
        @{ Name = 'BraveAIChatEnabled';  Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 121; Effect = 'feature' },
        @{ Name = 'BraveLocalAIEnabled'; Type = 'DWORD'; ApplyValue = 0; BraveDefault = 1; MinChromium = 149; Effect = 'feature' }
    )
}
