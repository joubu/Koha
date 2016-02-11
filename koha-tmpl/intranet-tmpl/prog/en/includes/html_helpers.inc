[% BLOCK options_for_authorised_value_categories %]
    [% FOREACH avc IN authorised_value_categories %]
        [% IF avc.selected %]
            <option value="[% avc.category %]" selected="selected">[% avc.category %]</option>
        [% ELSE %]
            <option value="[% avc.category %]">[% avc.category %]</option>
        [% END %]
    [% END %]
[% END %]
