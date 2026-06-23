from datetime import datetime
from io import BytesIO
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from openpyxl import Workbook
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.platypus import Image, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle
from reportlab.lib import colors
from reportlab.lib.utils import ImageReader

from app.models.entities import Collection


PHOTO_MAX_WIDTH = 320


def _photo_flowable(file_path: str):
    """Retorna um Image redimensionado se o arquivo existir no servidor, senao None."""
    if not file_path:
        return None
    path = Path(file_path)
    if not path.is_file():
        return None
    try:
        reader = ImageReader(str(path))
        src_w, src_h = reader.getSize()
        if not src_w or not src_h:
            return None
        width = min(PHOTO_MAX_WIDTH, src_w)
        height = width * src_h / src_w
        return Image(str(path), width=width, height=height)
    except Exception:
        return None


def _answer_map(collection: Collection) -> dict[str, object]:
    return {answer.field_key: answer.answer_value for answer in collection.answers}


def build_collections_xlsx(collections: list[Collection]) -> bytes:
    wb = Workbook()
    ws = wb.active
    ws.title = "Coletas"
    headers = [
        "ID da coleta",
        "Projeto",
        "Formulario",
        "Trecho",
        "Ponto/obra",
        "Data",
        "Arqueologo",
        "Latitude",
        "Longitude",
        "Descricao da atividade",
        "Vestigio identificado",
        "Qual vestigio",
        "Intercorrencia",
        "Qual intercorrencia",
        "Status",
        "Data de sincronizacao",
    ]
    ws.append(headers)
    for collection in collections:
        answers = _answer_map(collection)
        ws.append(
            [
                collection.id,
                collection.project.name if collection.project else "",
                collection.form.name if collection.form else "",
                collection.section.name if collection.section else "",
                collection.work_point.name if collection.work_point else collection.work_point_other or "",
                collection.collection_date.isoformat() if collection.collection_date else "",
                collection.user.name if collection.user else "",
                float(collection.latitude) if collection.latitude is not None else "",
                float(collection.longitude) if collection.longitude is not None else "",
                answers.get("activity_description", ""),
                answers.get("vestigio_identificado", ""),
                answers.get("qual_vestigio", ""),
                answers.get("intercorrencia_identificada", ""),
                answers.get("qual_intercorrencia", ""),
                collection.status,
                collection.synced_at.isoformat() if collection.synced_at else "",
            ]
        )
    for column_cells in ws.columns:
        max_length = max(len(str(cell.value or "")) for cell in column_cells)
        ws.column_dimensions[column_cells[0].column_letter].width = min(max(max_length + 2, 14), 44)
    output = BytesIO()
    wb.save(output)
    return output.getvalue()


def build_collection_pdf(collection: Collection) -> bytes:
    output = BytesIO()
    doc = SimpleDocTemplate(output, pagesize=A4, title="Ficha de Campo")
    styles = getSampleStyleSheet()
    logo_path = Path(__file__).resolve().parents[3] / "frontend" / "src" / "assets" / "brandt-logo.png"
    answers = _answer_map(collection)
    data = [
        ["Projeto", collection.project.name if collection.project else ""],
        ["Formulario", collection.form.name if collection.form else ""],
        ["Trecho", collection.section.name if collection.section else ""],
        ["Ponto/obra", collection.work_point.name if collection.work_point else collection.work_point_other or ""],
        ["Data", collection.collection_date.isoformat() if collection.collection_date else ""],
        ["Arqueologo", collection.user.name if collection.user else ""],
        ["Coordenadas", f"{collection.latitude}, {collection.longitude}"],
        ["Descricao", answers.get("activity_description", "")],
        ["Vestigio", f"{answers.get('vestigio_identificado', '')} - {answers.get('qual_vestigio', '')}"],
        ["Intercorrencia", f"{answers.get('intercorrencia_identificada', '')} - {answers.get('qual_intercorrencia', '')}"],
    ]
    table = Table(data, colWidths=[120, 360])
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#F4F8F6")),
                ("TEXTCOLOR", (0, 0), (-1, -1), colors.HexColor("#10231F")),
                ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#DCE7E3")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("FONTNAME", (0, 0), (0, -1), "Helvetica-Bold"),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                ("TOPPADDING", (0, 0), (-1, -1), 7),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
            ]
        )
    )
    story = []
    if logo_path.exists():
        story.append(Image(str(logo_path), width=180, height=52))
        story.append(Spacer(1, 10))
    story.extend(
        [
            Paragraph("Ficha de Campo - Acompanhamento Arqueologico", styles["Title"]),
            Paragraph("Coleta, sincronizacao e gestao de campo", styles["BodyText"]),
            Spacer(1, 14),
            table,
            Spacer(1, 16),
            Paragraph("Fotos registradas", styles["Heading2"]),
        ]
    )
    if collection.photos:
        for photo in collection.photos:
            story.append(Paragraph(f"{photo.photo_type}: {photo.original_filename or photo.file_path}", styles["BodyText"]))
            image = _photo_flowable(photo.file_path)
            if image is not None:
                story.append(Spacer(1, 4))
                story.append(image)
            else:
                story.append(Paragraph("(imagem ainda nao sincronizada para o servidor)", styles["Italic"]))
            story.append(Spacer(1, 10))
    else:
        story.append(Paragraph("Nenhuma foto vinculada a esta coleta.", styles["BodyText"]))
    story.extend([Spacer(1, 14), Paragraph(f"Gerado em {datetime.utcnow().isoformat()} UTC", styles["Italic"])])
    doc.build(story)
    return output.getvalue()


def build_collections_kmz(collections: list[Collection]) -> bytes:
    placemarks = []
    for collection in collections:
        if collection.latitude is None or collection.longitude is None:
            continue
        answers = _answer_map(collection)
        point_name = collection.work_point.name if collection.work_point else collection.work_point_other or collection.id
        description = (
            f"Projeto: {collection.project.name if collection.project else ''}<br/>"
            f"Trecho: {collection.section.name if collection.section else ''}<br/>"
            f"Arqueologo: {collection.user.name if collection.user else ''}<br/>"
            f"Data: {collection.collection_date or ''}<br/>"
            f"Descricao: {answers.get('activity_description', '')}"
        )
        placemarks.append(
            f"""
      <Placemark>
        <name>{point_name}</name>
        <description><![CDATA[{description}]]></description>
        <Point><coordinates>{collection.longitude},{collection.latitude},0</coordinates></Point>
      </Placemark>"""
        )
    kml = f"""<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>Coletas Arqueologia Brandt</name>
    {''.join(placemarks)}
  </Document>
</kml>"""
    output = BytesIO()
    with ZipFile(output, "w", ZIP_DEFLATED) as kmz:
        kmz.writestr("doc.kml", kml)
    return output.getvalue()
