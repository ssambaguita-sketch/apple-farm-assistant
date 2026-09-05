import main
import orchard_management


@main.app.post("/api/orchards/{orchard_id}/remove")
def remove_orchard_post(orchard_id: int, x: orchard_management.OrchardDeleteIn):
    return orchard_management.delete_orchard(orchard_id, x)
