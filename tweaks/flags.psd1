# Flags tab: brave://flags entries written to Brave's Local State.
#
# A flag is only listed when it does something useful and has lasted: it must
# have been in brave://flags since Brave 1.85 or earlier (checked against
# brave-core browser/about_flags.cc at each release tag). Brave drops a flag
# name it no longer knows the next time it starts, so a flag that is removed
# later does no harm.
#
# Name is the brave://flags id. State is what a ticked row sets: 'enabled' or
# 'disabled'. Unticking puts the flag back to Default. MinBrave is the Brave
# minor version (the 85 of 1.85) the flag first shipped in; rows are greyed out
# on an older Brave. Descriptions are the strings flag.<Name>.description.
# Effect and Impacts are tags from tweaks\tags.psd1.
@{
    Flags = @(
        @{ Name = 'brave-round-time-stamps';                 State = 'enabled';  MinBrave = 50; Effect = 'protection' }
        @{ Name = 'brave-show-strict-fingerprinting-mode';   State = 'enabled';  MinBrave = 65; Effect = 'protection' }
        @{ Name = 'brave-clean-link-js-api';                 State = 'enabled';  MinBrave = 80; Effect = 'privacy' }
        @{ Name = 'brave-extension-network-blocking';        State = 'enabled';  MinBrave = 45; Effect = 'protection'; Impacts = @('mayBreakSites') }
        @{ Name = 'brave-adblock-default-1p-blocking';       State = 'enabled';  MinBrave = 45; Effect = 'protection'; Impacts = @('mayBreakSites') }
        @{ Name = 'brave-adblock-experimental-list-default'; State = 'enabled';  MinBrave = 70; Effect = 'protection'; Impacts = @('mayBreakSites') }
        @{ Name = 'brave-request-otr-tab';                   State = 'enabled';  MinBrave = 55; Effect = 'privacy' }
        @{ Name = 'brave-news-peek';                         State = 'disabled'; MinBrave = 45; Effect = 'clutter' }
        @{ Name = 'brave-ntp-search-widget';                 State = 'disabled'; MinBrave = 70; Effect = 'clutter' }
    )
}
