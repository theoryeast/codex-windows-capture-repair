# Attribution and scope

This project is an independent, unofficial compatibility utility. It is not
affiliated with or endorsed by OpenAI or Microsoft. Product names belong to
their respective owners.

The callback-deferral approach was informed by public reproductions and source
discussion in [openai/codex#49383](https://github.com/openai/codex/issues/49383),
including the MTA investigation shared by iamjangpa. Thanks to the reporters and
independent testers who narrowed the failure down.

The dispatcher in `native/dispatcher.asm` is independently implemented for this
repository. Its emitted template is generated from this repository's source and
checked against assembler output. No third-party source archive or its compiled
dispatcher is bundled.

The MIT license covers this repository's code and documentation. No license is
granted here for OpenAI's software. The repository contains software fingerprints
and PE metadata, but no original or modified OpenAI executable, certificate,
debug symbol, private screenshot, or machine log. Each user supplies their own
installed helper; originals and generated candidates remain on that user's PC.
