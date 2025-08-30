# Test File with Empty Answer Lines

This file tests the specific case reported by the user.

---
<!--ID:1690041467827-->
1. How to create a mutable global Config singleton?

> - use the [config - Rust](https://docs.rs/config/latest/config/) crate: allows for stacked config
> - mutability via RW lock
>
> ```rust
> use config::Config;
> use lazy_static::lazy_static;
> use std::error::Error;
> use std::sync::RwLock;
>
> lazy_static! {
>     static ref SETTINGS: RwLock<Config> = RwLock::new(Config::default());
> }
> fn try_main() -> Result<(), Box<dyn Error>> {
>     // Set property
>     SETTINGS.write()?.set("property", 42)?;
>     // Get property
>     println!("property: {}", SETTINGS.read()?.get::<i32>("property")?);
>     Ok(())
> }
> fn main() {
>     try_main().unwrap();
> }
> ```

---

This file has empty answer lines (lines with just ">") that should be handled correctly.