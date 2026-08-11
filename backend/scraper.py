import requests

def fetch_daraz_alternatives(query, page=1):
    url = f"https://www.daraz.pk/catalog/?ajax=true&isFirstRequest=true&page={page}&q={query}"
    
    headers = {
        "accept": "*/*",
        "accept-language": "en-GB,en-US;q=0.9,en;q=0.8",
        "user-agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) "
                      "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1",
        "referer": f"https://www.daraz.pk/catalog/?q={query}",
    }

    cookies = {}

    try:
        response = requests.get(url, headers=headers, cookies=cookies)
        response.raise_for_status()
        data = response.json()
    except requests.RequestException as e:
        print("Daraz scraper error:", e)
        return []
    except ValueError:
        print("Daraz returned invalid JSON")
        return []

    products = data.get('mods', {}).get('listItems', [])
    
    result = []
    for p in products:
        price = p.get('price')
        if isinstance(price, dict):
            price_val = price.get('originalPrice') or price.get('formattedPrice')
        else:
            price_val = price or "N/A"

        image = p.get('image')
        if isinstance(image, dict):
            image_val = image.get('url')
        else:
            image_val = image or ""

        result.append({
            "name": p.get('name', "No name"),
            "price": price_val,
            "image": image_val,
            "link": p.get('productUrl', "")
        })
    
    return result


def fetch_all_categories(categories):
    """
    Fetch all categories and return a dict: {category_name: [products]}
    """
    all_products = {}
    for cat in categories:
        products = fetch_daraz_alternatives(cat)
        if products:
            all_products[cat] = products
    return all_products
